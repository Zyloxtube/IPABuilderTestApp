from pathlib import Path

path = Path("IPABuilderTestApp.swift")
source = path.read_text(encoding="utf-8")

def replace_once(old, new, label):
    global source
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"Patch failed for {label}: expected one match, found {count}")
    source = source.replace(old, new, 1)

replace_once(
'''        .textInputAutocapitalization(isEmail ? .never : .words)''',
'''        .textInputAutocapitalization(.never)''',
"username autocapitalization"
)

replace_once(
'''    static func follow(username: String) async throws {
        let safeUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let body = try JSONSerialization.data(withJSONObject: ["username": username])
        _ = try await request("api/users/\\\\(safeUsername)/follow", method: "POST", body: body)
    }''',
'''    static func follow(username: String) async throws -> [String: Any] {
        let safeUsername = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let (profileData, _) = try await request("api/users/\\\\(safeUsername)")
        let profileJSON = (try? JSONSerialization.jsonObject(with: profileData)) as? [String: Any] ?? [:]
        guard let user = profileJSON["user"] as? [String: Any],
              let userID = user["id"] as? String, !userID.isEmpty else {
            throw NSError(domain: "LerizAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "This profile could not be found."])
        }
        let (data, _) = try await request("api/users/\\\\(userID)/follow", method: "POST", body: Data("{}".utf8))
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }''',
"follow resolves username to server user id"
)

replace_once(
'''                        .overlay {
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
'''                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { isPlaying.toggle() }
                    }''',
"video tap does not use a full-screen button that blocks action controls"
)

replace_once(
'''                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        player.isMuted = false
                        if isActive { player.play() }
                    }''',
'''                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        player.isMuted = false
                        if isActive { player.play(); isPlaying = true }
                    }''',
"sync initial video playing state"
)

replace_once(
'''        .onAppear { if isActive { player.play() } }
        .sheet(isPresented: $showHashtagPage) { HashtagVideosSheet(tag: tappedHashtag) }''',
'''        .onAppear {
            if isActive {
                player.play()
                isPlaying = true
            }
        }
        .sheet(isPresented: $showHashtagPage) { HashtagVideosSheet(tag: tappedHashtag) }''',
"sync player state when page appears"
)

replace_once(
'''                    let insertionIndex: Int
                    if let parentID, let parentIndex = commentIDs.firstIndex(of: parentID) {
                        insertionIndex = parentIndex + 1
                    } else {
                        insertionIndex = 0
                    }''',
'''                    let insertionIndex: Int
                    if let parentID, let parentIndex = commentIDs.firstIndex(of: parentID) {
                        let existingReplyIndexes = commentParentIDs.indices.filter { commentParentIDs[$0] == parentID }
                        insertionIndex = (existingReplyIndexes.max() ?? parentIndex) + 1
                    } else {
                        insertionIndex = posted.count
                    }''',
"append root comments and place replies after existing replies"
)

replace_once(
'''        guard let hash = text.lastIndex(of: "#") else { activeHashtag = ""; hashtagMatches = []; return }
        let start = text.index(after: hash)
        let suffix = text[start...]
        guard !suffix.contains(where: { $0.isWhitespace || $0 == "#" }) else { activeHashtag = ""; hashtagMatches = []; return }
        let prefix = String(suffix)
        guard !prefix.isEmpty else { activeHashtag = ""; hashtagMatches = []; return }
        activeHashtag = prefix''',
'''        guard let hash = text.lastIndex(of: "#") else { activeHashtag = ""; hashtagMatches = []; return }
        let start = text.index(after: hash)
        let suffix = text[start...]
        guard !suffix.contains(where: { $0.isWhitespace || $0 == "#" }) else { activeHashtag = ""; hashtagMatches = []; return }
        let prefix = String(suffix)
        activeHashtag = prefix''',
"show hashtag actions as soon as a hash is typed"
)

replace_once(
'''                            await MainActor.run { showDeleteError = "Profile picture upload failed: (error.localizedDescription)" }''',
'''                            await MainActor.run { showDeleteError = "Profile picture upload failed: \\\\(error.localizedDescription)" }''',
"avatar upload error interpolation"
)

replace_once(
'''                                     _ = try await LerizAPI.saveProfile(displayName: name, username: username, bio: bio)
                                     await MainActor.run { saving = false; saved = true }''',
'''                                     let updated = try await LerizAPI.saveProfile(displayName: name, username: username, bio: bio)
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
"persist profile changes in app defaults"
)

replace_once(
'''                                     do { try await LerizAPI.follow(username: (profileUser["id"] as? String) ?? "") }
                                     catch { await MainActor.run { profileLoadError = error.localizedDescription } }''',
'''                                     do {
                                         let username = profileUser["username"] as? String ?? clip?.handle.replacingOccurrences(of: "@", with: "") ?? ""
                                         let result = try await LerizAPI.follow(username: username)
                                         await MainActor.run { profileUser["isFollowing"] = result["isFollowing"] as? Bool ?? !(profileUser["isFollowing"] as? Bool ?? false) }
                                     } catch { await MainActor.run { profileLoadError = error.localizedDescription } }''',
"follow profile with username and update state"
)

replace_once(
'''                            await MainActor.run { showDeleteError = "Profile picture upload failed: (error.localizedDescription)" }''',
'''                            await MainActor.run { showDeleteError = "Profile picture upload failed: \\\\(error.localizedDescription)" }''',
"avatar error interpolation"
)

path.write_text(source, encoding="utf-8")
print("Applied all Leriz client patches.")
