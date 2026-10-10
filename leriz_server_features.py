from __future__ import annotations

"""
Leriz server feature extension.

Keep this file beside the existing Flask server. In the server file, immediately
after all existing routes have been declared and before app.run(...), add:

    from leriz_server_features import install_features
    install_features(app, globals())

It preserves the existing SQLite database and adds profile edits/deletion,
verified usernames, nested replies, comment likes, and hashtag discovery.
"""
import re
import sqlite3
import uuid
from pathlib import Path
from flask import request, jsonify, send_file


VERIFIED_USERNAMES = {"tjadev", "yzndev"}
HASHTAG_RE = re.compile(r"(?<![A-Za-z0-9_])#([A-Za-z0-9_]{1,50})")


def install_features(app, ns):
    connect_db = ns["connect_db"]
    current_user = ns["current_user"]
    require_auth = ns["require_auth"]
    fail = ns["fail"]
    body = ns["body"]
    clean = ns["clean"]
    now = ns["now"]
    create_notification = ns["create_notification"]
    DATA = Path(ns["DATA"])
    VIDEOS = Path(ns["VIDEOS"])
    AVATARS = Path(ns["AVATARS"])

    def migrate():
        with connect_db() as db:
            columns = {r["name"] for r in db.execute("PRAGMA table_info(comments)")}
            if "parent_id" not in columns:
                db.execute("ALTER TABLE comments ADD COLUMN parent_id TEXT REFERENCES comments(id) ON DELETE CASCADE")
            db.execute("""
                CREATE TABLE IF NOT EXISTS comment_likes (
                    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    comment_id TEXT NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY(user_id, comment_id)
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS hashtags (
                    name TEXT PRIMARY KEY COLLATE NOCASE,
                    description TEXT NOT NULL DEFAULT '',
                    created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
                    created_at TEXT NOT NULL
                )
            """)
            db.execute("CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON comment_likes(comment_id)")
    migrate()

    original_public_user = ns["public_user"]
    def public_user_with_verified(row, viewer_id=None):
        result = original_public_user(row, viewer_id)
        result["verified"] = str(result.get("username", "")).casefold() in VERIFIED_USERNAMES
        return result
    ns["public_user"] = public_user_with_verified

    original_public_video = ns["public_video"]
    def public_video_with_verified(row, viewer_id=None):
        result = original_public_video(row, viewer_id)
        if result.get("user"):
            result["user"]["verified"] = str(result["user"].get("username", "")).casefold() in VERIFIED_USERNAMES
        result["hashtags"] = ["#" + tag for tag in HASHTAG_RE.findall(result.get("caption", ""))]
        return result
    ns["public_video"] = public_video_with_verified

    def add_comment(video_id):
        user = current_user()
        data = body()
        text = clean(data.get("text"), 1000)
        parent_id = clean(data.get("parentId") or data.get("parentID"), 80) or None
        if not text:
            return fail("Comment cannot be empty.")
        comment_id, created = str(uuid.uuid4()), now()
        with connect_db() as db:
            video = db.execute("SELECT user_id FROM videos WHERE id=?", (video_id,)).fetchone()
            if not video:
                return fail("Video not found.", 404)
            if parent_id and not db.execute(
                "SELECT 1 FROM comments WHERE id=? AND video_id=?", (parent_id, video_id)
            ).fetchone():
                return fail("Reply target not found for this video.", 404)
            db.execute(
                "INSERT INTO comments(id,user_id,video_id,text,created_at,parent_id) VALUES(?,?,?,?,?,?)",
                (comment_id, user["id"], video_id, text, created, parent_id)
            )
            create_notification(db, video["user_id"], user["id"], "reply" if parent_id else "comment", video_id, comment_id)
            user_row = db.execute("SELECT * FROM users WHERE id=?", (user["id"],)).fetchone()
        return jsonify({"ok": True, "comment": {
            "id": comment_id, "videoID": video_id, "text": text,
            "createdAt": created, "parentID": parent_id,
            "user": {"id": user["id"], "username": user["username"],
                     "displayName": user["display_name"],
                     "avatarURL": ns["avatar_url"](user["id"]) if user["avatar_file"] else ""}
        }}), 201

    def list_comments(video_id):
        limit, offset = ns["page_args"](default=50, maximum=100)
        if not ns["get_video"](video_id):
            return fail("Video not found.", 404)
        viewer = current_user()
        viewer_id = viewer["id"] if viewer else None
        with connect_db() as db:
            rows = db.execute("""
                SELECT c.*,u.username,u.display_name,u.avatar_file,
                    (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id=c.id) AS likes,
                    EXISTS(SELECT 1 FROM comment_likes cl WHERE cl.comment_id=c.id AND cl.user_id=?) AS liked_by_me
                FROM comments c JOIN users u ON u.id=c.user_id
                WHERE c.video_id=?
                ORDER BY c.created_at ASC LIMIT ? OFFSET ?
            """, (viewer_id or "", video_id, limit, offset)).fetchall()
        return jsonify({"ok": True, "comments": [{
            "id": r["id"], "videoID": r["video_id"], "text": r["text"],
            "createdAt": r["created_at"], "parentID": r["parent_id"],
            "likes": r["likes"], "likedByMe": bool(r["liked_by_me"]),
            "user": {"id": r["user_id"], "username": r["username"],
                     "displayName": r["display_name"],
                     "avatarURL": ns["avatar_url"](r["user_id"]) if r["avatar_file"] else ""}
        } for r in rows]})

    def toggle_comment_like(comment_id):
        user = current_user()
        with connect_db() as db:
            if not db.execute("SELECT 1 FROM comments WHERE id=?", (comment_id,)).fetchone():
                return fail("Comment not found.", 404)
            exists = db.execute("SELECT 1 FROM comment_likes WHERE user_id=? AND comment_id=?",
                                (user["id"], comment_id)).fetchone()
            if exists:
                db.execute("DELETE FROM comment_likes WHERE user_id=? AND comment_id=?", (user["id"], comment_id))
                liked = False
            else:
                db.execute("INSERT INTO comment_likes VALUES(?,?,?)", (user["id"], comment_id, now()))
                liked = True
            count = db.execute("SELECT COUNT(*) FROM comment_likes WHERE comment_id=?", (comment_id,)).fetchone()[0]
        return jsonify({"ok": True, "liked": liked, "likes": count})

    def edit_me():
        user = current_user()
        data = body()
        display_name = clean(data.get("displayName", user["display_name"]), 60)
        bio = clean(data.get("bio", user["bio"]), 300)
        username = clean(data.get("username", user["username"]), 30).lstrip("@")
        if not re.fullmatch(r"[A-Za-z0-9_.]{3,30}", username):
            return fail("Username must be 3-30 letters, numbers, dots or underscores.")
        with connect_db() as db:
            collision = db.execute("SELECT id FROM users WHERE username=? COLLATE NOCASE AND id!=?",
                                   (username, user["id"])).fetchone()
            if collision:
                return fail("Username is already taken.", 409)
            db.execute("UPDATE users SET username=?,display_name=?,bio=? WHERE id=?",
                       (username, display_name or username, bio, user["id"]))
            updated = db.execute("SELECT * FROM users WHERE id=?", (user["id"],)).fetchone()
        return jsonify({"ok": True, "user": public_user_with_verified(updated, user["id"])})

    def delete_account():
        user = current_user()
        with connect_db() as db:
            videos = db.execute("SELECT filename FROM videos WHERE user_id=?", (user["id"],)).fetchall()
            avatar = db.execute("SELECT avatar_file FROM users WHERE id=?", (user["id"],)).fetchone()
            db.execute("DELETE FROM users WHERE id=?", (user["id"],))
        for row in videos:
            (VIDEOS / row["filename"]).unlink(missing_ok=True)
        if avatar and avatar["avatar_file"]:
            (AVATARS / avatar["avatar_file"]).unlink(missing_ok=True)
        return jsonify({"ok": True, "message": "Account deleted."})

    def discover_hashtags():
        query = clean(request.args.get("q", ""), 50).lstrip("#").casefold()
        limit = max(1, min(request.args.get("limit", 25, type=int) or 25, 25))
        with connect_db() as db:
            captions = db.execute("SELECT caption FROM videos").fetchall()
            known = set()
            for row in captions:
                known.update(tag.casefold() for tag in HASHTAG_RE.findall(row["caption"] or ""))
            for tag in known:
                db.execute("INSERT OR IGNORE INTO hashtags(name,description,created_at) VALUES(?,?,?)",
                           (tag, "", now()))
            rows = db.execute("""
                SELECT h.name,h.description,COUNT(DISTINCT v.id) AS videos
                FROM hashtags h LEFT JOIN videos v ON instr(lower(v.caption), '#' || lower(h.name)) > 0
                WHERE lower(h.name) LIKE ? ORDER BY h.created_at DESC,h.name LIMIT ?
            """, (query + "%", limit)).fetchall()
        return jsonify({"ok": True, "hashtags": [{
            "name": r["name"], "tag": "#" + r["name"], "description": r["description"],
            "videoCount": r["videos"]
        } for r in rows]})

    def create_hashtag():
        user = current_user()
        data = body()
        name = clean(data.get("name") or data.get("hashtag"), 50).lstrip("#").casefold()
        description = clean(data.get("description"), 500)
        if not re.fullmatch(r"[A-Za-z0-9_]{1,50}", name):
            return fail("Hashtags may contain only letters, numbers and underscores.")
        with connect_db() as db:
            db.execute("INSERT OR IGNORE INTO hashtags(name,description,created_by,created_at) VALUES(?,?,?,?)",
                       (name, description, user["id"], now()))
            if description:
                db.execute("UPDATE hashtags SET description=? WHERE name=? AND (description='' OR created_by=?)",
                           (description, name, user["id"]))
            row = db.execute("SELECT name,description FROM hashtags WHERE name=?", (name,)).fetchone()
        return jsonify({"ok": True, "hashtag": {"name": row["name"], "tag": "#" + row["name"],
                                               "description": row["description"]}}), 201

    def hashtag_videos(tag):
        name = clean(tag, 50).lstrip("#")
        if not re.fullmatch(r"[A-Za-z0-9_]{1,50}", name):
            return fail("Invalid hashtag.")
        limit, offset = ns["page_args"]()
        viewer = current_user()
        with connect_db() as db:
            rows = db.execute("""
                SELECT * FROM videos
                WHERE lower(caption) LIKE ?
                ORDER BY created_at DESC LIMIT ? OFFSET ?
            """, ("%#" + name.casefold() + "%", limit, offset)).fetchall()
        return jsonify({"ok": True, "hashtag": "#" + name, "videos": [
            public_video_with_verified(row, viewer["id"] if viewer else None) for row in rows
        ]})

    # Replace the original view functions so existing URLs keep working.
    app.view_functions["add_comment"] = require_auth(add_comment)
    app.view_functions["list_comments"] = list_comments
    app.view_functions["edit_me"] = require_auth(edit_me)
    app.add_url_rule("/api/comments/<comment_id>/like", "leriz_toggle_comment_like",
                     require_auth(toggle_comment_like), methods=["POST"])
    app.add_url_rule("/api/me", "leriz_delete_account", require_auth(delete_account), methods=["DELETE"])
    app.add_url_rule("/api/hashtags", "leriz_discover_hashtags", discover_hashtags, methods=["GET"])
    app.add_url_rule("/api/hashtags", "leriz_create_hashtag", require_auth(create_hashtag), methods=["POST"])
    app.add_url_rule("/api/hashtags/<tag>", "leriz_hashtag_videos", hashtag_videos, methods=["GET"])
