from pathlib import Path

p = Path("IPABuilderTestApp.swift")
s = p.read_text(encoding="utf-8")

def sub(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {n}")
    s = s.replace(old, new, 1)

sub(
r'''        .textInputAutocapitalization(isEmail ? .never : .words)''',
r'''        .textInputAutocapitalization(.never)''',
"username capitalization"
)

sub(
r'''    static func follow(username: String) async throws {
        let safeUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let body = try JSONSerialization.data(withJSONObject: ["username": username])
        _ = try await request("api/users/\(safeUsername)/follow", method: "POST", body: body)
    }''',
r'''    static func follow(username: String) async throws -> [String: Any] {
        let safeUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let (profileData, _) = try await request("api/users/\(safeUsername)")
        let profileJSON = (try? JSONSerialization.jsonObject(with: profileData)) as? [String: Any] ?? [:]
        guard let user = profileJSON["user"] as? [String: Any],
              let userID = user["id"] as? String, !userID.isEmpty else {
            throw NSError(domain: "LerizAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "This profile could not be found."])
        }
        let (data, _) = try await request("api/users/\(userID)/follow", method: "POST", body: Data("{}".utf8))
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }''',
"follow by user id"
)

sub(
r'''                    .overlay {
                        Button {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { isPlaying.toggle() }
                        } label: {
                            ZStack {
                                Color.clear.contentShape(Rectangle())
                                if !isPlaying {
                                    Circle().fill(.black.opacity(0.55)).frame(width: 66, height: 66)
                                        .overlay(Image(systemName: "play.fill").font(.system(size: 25, weight: .bold)).foregroundStyle(.white).offset(x: 2))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }''',
r'''                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { isPlaying.toggle() }
                    }''',
"video tap gesture"
)

sub(
r'''                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        player.isMuted = false
                        if isActive { player.play() }
                    }''',
r'''                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        player.isMuted = false
                        if isActive { player.play(); isPlaying = true }
                    }''',
"initial player state"
)

sub(
r'''        .onAppear { if isActive { player.play() } }
        .sheet(isPresented: $showHashtagPage) { HashtagVideosSheet(tag: tappedHashtag) }''',
r'''        .onAppear {
            if isActive {
                player.play()
                isPlaying = true
            }
        }
        .sheet(isPresented: $showHashtagPage) { HashtagVideosSheet(tag: tappedHashtag) }''',
"player appearance state"
)

sub(
r'''                    let insertionIndex: Int
                    if let parentID, let parentIndex = commentIDs.firstIndex(of: parentID) {
                        insertionIndex = parentIndex + 1
                    } else {
                        insertionIndex = 0
                    }''',
r'''                    let insertionIndex: Int
                    if let parentID, let parentIndex = commentIDs.firstIndex(of: parentID) {
                        let existingReplyIndexes = commentParentIDs.indices.filter { commentParentIDs[$0] == parentID }
                        insertionIndex = (existingReplyIndexes.max() ?? parentIndex) + 1
                    } else {
                        insertionIndex = posted.count
                    }''',
"comment ordering"
)

sub(
r'''        guard let hash = text.lastIndex(of: "#") else { activeHashtag = ""; hashtagMatches = []; return }
        let start = text.index(after: hash)
        let suffix = text[start...]
        guard !suffix.contains(where: { $0.isWhitespace || $0 == "#" }) else { activeHashtag = ""; hashtagMatches = []; return }
        let prefix = String(suffix)
        guard !prefix.isEmpty else { activeHashtag = ""; hashtagMatches = []; return }
        activeHashtag = prefix''',
r'''        guard let hash = text.lastIndex(of: "#") else { activeHashtag = ""; hashtagMatches = []; return }
        let start = text.index(after: hash)
        let suffix = text[start...]
        guard !suffix.contains(where: { $0.isWhitespace || $0 == "#" }) else { activeHashtag = ""; hashtagMatches = []; return }
        let prefix = String(suffix)
        activeHashtag = prefix''',
"hashtag suggestions after hash"
)

sub(
r'''                            await MainActor.run { showDeleteError = "Profile picture upload failed: (error.localizedDescription)" }''',
r'''                            await MainActor.run { showDeleteError = "Profile picture upload failed: \(error.localizedDescription)" }''',
"avatar error message"
)

sub(
r'''                                    _ = try await LerizAPI.saveProfile(displayName: name, username: username, bio: bio)
                                    await MainActor.run { saving = false; saved = true }''',
r'''                                     let updated = try await LerizAPI.saveProfile(displayName: name, username: username, bio: bio)
                                     await MainActor.run {
                                         if let value = updated["username"] as? String, !value.isEmpty {
                                             self.username = value
                                             UserDefaults.standard.set(value, forKey: "lerizUsername")
                                         }
                                         if let value = updated["displayName"] as? String {
                                             self.name = value
                                             UserDefaults.standard.set(value, forKey: "lerizDisplayName")
                                         }
                                         if let value = updated["bio"] as? String {
                                             self.bio = value
                                             UserDefaults.standard.set(value, forKey: "lerizBio")
                                         }
                                         saving = false
                                         saved = true
                                     }''',
"save profile defaults"
)

sub(
r'''                                    do { try await LerizAPI.follow(username: (profileUser["id"] as? String) ?? "") }
                                    catch { await MainActor.run { profileLoadError = error.localizedDescription } }''',
r'''                                     do {
                                         let username = profileUser["username"] as? String ?? clip?.handle.replacingOccurrences(of: "@", with: "") ?? ""
                                         let result = try await LerizAPI.follow(username: username)
                                         await MainActor.run {
                                             profileUser["isFollowing"] = result["isFollowing"] as? Bool ?? !(profileUser["isFollowing"] as? Bool ?? false)
                                         }
                                     } catch { await MainActor.run { profileLoadError = error.localizedDescription } }''',
"profile follow action"
)

sub(
r'''                            HStack(alignment: .top, spacing: 11) {
                                Circle().fill(LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 38, height: 38)''',
r'''                            let isReply = index < commentParentIDs.count && commentParentIDs[index] != nil
                            HStack(alignment: .top, spacing: 11) {
                                Circle().fill(LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: isReply ? 27 : 38, height: isReply ? 27 : 38)''',
"smaller reply avatar"
)

sub(
r'''                                    Text(text).font(.system(size: 14))''',
r'''                                    Text(text).font(.system(size: isReply ? 12 : 14))''',
"smaller reply text"
)

sub(
r'''            let rows = try await LerizAPI.fetchComments(videoID: videoID)
            await MainActor.run {
                posted = rows.compactMap { $0["text"] as? String }''',
r'''            let rows = try await LerizAPI.fetchComments(videoID: videoID)
            let roots = rows.filter { ($0["parentID"] ?? $0["parentId"]) == nil || ($0["parentID"] as? String ?? $0["parentId"] as? String ?? "").isEmpty }
            var orderedRows: [[String: Any]] = []
            for root in roots {
                orderedRows.append(root)
                let rootID = root["id"] as? String ?? ""
                orderedRows.append(contentsOf: rows.filter {
                    (($0["parentID"] ?? $0["parentId"]) as? String) == rootID
                })
            }
            let includedIDs = Set(orderedRows.compactMap { $0["id"] as? String })
            orderedRows.append(contentsOf: rows.filter { row in
                guard let id = row["id"] as? String else { return false }
                return !includedIDs.contains(id)
            })
            await MainActor.run {
                posted = orderedRows.compactMap { $0["text"] as? String }''',
"order replies directly below their parent"
)

sub(
r'''                commentIDs = rows.enumerated().map { index, row in''',
r'''                commentIDs = orderedRows.enumerated().map { index, row in''',
"ordered comment ids"
)
sub(
r'''                commentAuthors = rows.map { row in''',
r'''                commentAuthors = orderedRows.map { row in''',
"ordered comment authors"
)
sub(
r'''                commentParentIDs = rows.map { row in''',
r'''                commentParentIDs = orderedRows.map { row in''',
"ordered comment parents"
)

sub(
r'''    @State private var showCreateHashtag = false
    @State private var showHashtagSearch = false''',
r'''    @State private var showCreateHashtag = false
    @State private var showHashtagSearch = false
    @State private var showHashtagPopup = false''',
"hashtag popup visibility state"
)
sub(
r'''            if !activeHashtag.isEmpty {
                VStack(alignment: .leading, spacing: 0) {''',
r'''            if showHashtagPopup {
                VStack(alignment: .leading, spacing: 0) {''',
"show hashtag popup when # has no letters yet"
)
sub(
r'''        guard let hash = text.lastIndex(of: "#") else { activeHashtag = ""; hashtagMatches = []; return }''',
r'''        guard let hash = text.lastIndex(of: "#") else { activeHashtag = ""; hashtagMatches = []; showHashtagPopup = false; return }''',
"hide hashtag popup when hash removed"
)
sub(
r'''        guard !suffix.contains(where: { $0.isWhitespace || $0 == "#" }) else { activeHashtag = ""; hashtagMatches = []; return }''',
r'''        guard !suffix.contains(where: { $0.isWhitespace || $0 == "#" }) else { activeHashtag = ""; hashtagMatches = []; showHashtagPopup = false; return }''',
"hide hashtag popup when token ends"
)
sub(
r'''        let prefix = String(suffix)
        activeHashtag = prefix
        Task {''',
r'''        let prefix = String(suffix)
        activeHashtag = prefix
        showHashtagPopup = true
        Task {''',
"open hashtag popup"
)
sub(
r'''        activeHashtag = ""
        hashtagMatches = []
    }

    private func renderTextIntoVideo''',
r'''        activeHashtag = ""
        hashtagMatches = []
        showHashtagPopup = false
    }

    private func renderTextIntoVideo''',
"close hashtag popup after selection"
)

p.write_text(s, encoding="utf-8")
print("Leriz client patches applied.")
