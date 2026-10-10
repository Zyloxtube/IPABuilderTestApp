# Leriz Flask server feature patch

The iOS app uses the existing Leriz Flask API. Keep `leriz_server_features.py` beside the current Python server file, then add these two lines **after the original API routes have been declared and before the `if __name__ == "__main__":` block**:

```python
from leriz_server_features import install_features
install_features(app, globals())
```

Restart the Flask server after saving. The first startup runs safe SQLite migrations on the existing `leriz.sqlite3` database.

This patch adds:
- `PATCH /api/me`: update display name, username, and bio.
- `DELETE /api/me`: delete the authenticated account and its stored video/avatar files.
- Verified flags for the exact usernames `TJADev` and `yzndev` (case-insensitive).
- Persistent parent IDs for replies, nested comment responses, and comment likes.
- `GET /api/hashtags?q=prefix&limit=25`, `POST /api/hashtags`, and `GET /api/hashtags/<tag>`.
- Hashtag discovery from existing video captions, so old videos can be found without re-uploading.

Profile pictures are uploaded through the original `POST /api/me/avatar` endpoint, which already exists in the supplied server.

The app's login screen now sends the **username** expected by `POST /api/auth/login` (not an email field). The saved bearer token is checked with `GET /api/me` on launch to restore the signed-in session. The server itself still must be running and reachable at the URL configured in `server.json`.
