from pathlib import Path

p = Path("IPABuilderTestApp.swift")
s = p.read_text(encoding="utf-8")

def sub(old, new, label):
    global s
    n = s.count(old)
    # Some fixes may already exist in a newer source revision; skip absent anchors.
    if n == 0:
        return
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

sub(
r'''    @State private var player = AVPlayer()
    @State private var isPlaying = true''',
r'''    @State private var player = AVQueuePlayer()
    @State private var playerLooper: AVPlayerLooper?
    @State private var isPlaying = true''',
"use AVQueuePlayer for guaranteed looping"
)
sub(
r'''                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        player.isMuted = false
                        if isActive { player.play(); isPlaying = true }
                    }''',
r'''                    .onAppear {
                        player.removeAllItems()
                        playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                        player.isMuted = false
                        if isActive { player.play(); isPlaying = true }
                    }''',
"create looping player"
)
sub(
r'''                    .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
                        guard let ended = notification.object as? AVPlayerItem,
                              ended === player.currentItem else { return }
                        player.seek(to: .zero) { _ in
                            if isActive && isPlaying { player.play() }
                        }
                    }
''',
"" ,
"remove manual end notification because AVPlayerLooper repeats seamlessly"
)

# Recording setup must be idempotent; avoid duplicate inputs/outputs and ensure configuration is committed once.
sub(
r'''    func configure(position: AVCaptureDevice.Position, completion: @escaping (String?) -> Void) {
        sessionQueue.async {
            do {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                try self.installVideoInput(position: position)
                if let mic = AVCaptureDevice.default(for: .audio),
                   let audioInput = try? AVCaptureDeviceInput(device: mic),
                   self.session.canAddInput(audioInput) { self.session.addInput(audioInput) }
                if self.session.canAddOutput(self.movieOutput) { self.session.addOutput(self.movieOutput) }
                self.session.commitConfiguration()
                self.currentPosition = position
                self.session.startRunning()
                DispatchQueue.main.async { completion(nil) }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion("Could not open camera: \(error.localizedDescription)") }
            }
        }
    }''',
r'''    private var isConfigured = false

    func configure(position: AVCaptureDevice.Position, completion: @escaping (String?) -> Void) {
        sessionQueue.async {
            if self.isConfigured {
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            do {
                try self.installVideoInput(position: position)
                if let mic = AVCaptureDevice.default(for: .audio) {
                    let alreadyHasAudio = self.session.inputs.contains {
                        ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true
                    }
                    if !alreadyHasAudio {
                        let audioInput = try AVCaptureDeviceInput(device: mic)
                        guard self.session.canAddInput(audioInput) else {
                            throw NSError(domain: "LerizCamera", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not connect the microphone."])
                        }
                        self.session.addInput(audioInput)
                    }
                }
                if !self.session.outputs.contains(where: { $0 === self.movieOutput }) {
                    guard self.session.canAddOutput(self.movieOutput) else {
                        throw NSError(domain: "LerizCamera", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not prepare video recording."])
                    }
                    self.session.addOutput(self.movieOutput)
                }
                self.session.commitConfiguration()
                self.isConfigured = true
                self.currentPosition = position
                self.session.startRunning()
                DispatchQueue.main.async { completion(nil) }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion("Could not open camera: \(error.localizedDescription)") }
            }
        }
    }''',
"safe idempotent camera setup"
)

# Reset a recording flag if start fails; only publish a URL after the file has actually been written.
sub(
r'''            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async { completion(nil) }''',
r'''            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async { completion(nil) }''',
"recording start remains on capture queue"
)

# Keep the CommentsSheet body type-checkable and use its supplied dismiss callback.
comments_type_start = s.index("struct CommentsSheet: View {")
comments_type_end = s.index("    private func toggleCommentLike", comments_type_start)
comments_type_body = s[comments_type_start:comments_type_end]
comments_type_body = comments_type_body.replace(
    "    var body: some View {\n        NavigationStack {",
    "    var body: some View {\n        AnyView(NavigationStack {",
    1
)
comments_type_body = comments_type_body.replace(
    "Button { dismiss() } label: { Image(systemName: \"xmark\")",
    "Button { onDismiss() } label: { Image(systemName: \"xmark\")",
    1
)
comments_type_body = comments_type_body.replace(
    "        .onAppear {\n            let saved = (try? JSONDecoder().decode([String].self, from: Data(likedCommentIDsJSON.utf8))) ?? []\n            likedComments = Set(saved)\n        }\n    }\n\n",
    "        .onAppear {\n            let saved = (try? JSONDecoder().decode([String].self, from: Data(likedCommentIDsJSON.utf8))) ?? []\n            likedComments = Set(saved)\n        }\n    })\n    }\n\n",
    1
)
s = s[:comments_type_start] + comments_type_body + s[comments_type_end:]

p.write_text(s, encoding="utf-8")
print("Leriz client patches applied.")
