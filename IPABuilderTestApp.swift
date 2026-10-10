import SwiftUI
import Combine
import AVKit
import UIKit
import ARKit
import SceneKit
import ReplayKit
import AVFoundation
import CoreMedia
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct LerizServerConfiguration: Decodable {
    let serverName: String
    let baseURL: String

    static let current: LerizServerConfiguration = {
        guard
            let url = Bundle.main.url(forResource: "server", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(LerizServerConfiguration.self, from: data),
            URL(string: config.baseURL) != nil
        else {
            return LerizServerConfiguration(serverName: "Leriz Server", baseURL: "https://subhyaloid-kallie-bihourly.ngrok-free.dev")
        }
        return config
    }()
}


struct LerizAPI {
    static let baseURL = LerizServerConfiguration.current.baseURL
    static var token: String { UserDefaults.standard.string(forKey: "lerizAuthToken") ?? "" }

    static func request(_ path: String, method: String = "GET", body: Data? = nil, contentType: String = "application/json") async throws -> (Data, HTTPURLResponse) {
        guard let base = URL(string: baseURL), let url = URL(string: path, relativeTo: base) else {
            throw NSError(domain: "LerizAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Leriz server URL."])
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "LerizAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Leriz server."])
        }
        guard (200...299).contains(http.statusCode) else {
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            throw NSError(domain: "LerizAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: json["error"] as? String ?? "Leriz request failed (HTTP \(http.statusCode))."])
        }
        return (data, http)
    }

    static func fetchFeed(mode: String = "forYou") async throws -> [FeedClip] {
        let (data, _) = try await request("api/feed?mode=\(mode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mode)&limit=100&offset=0")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let rows = json["videos"] as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let id = row["id"] as? String, !id.isEmpty else { return nil }
            let user = row["user"] as? [String: Any] ?? [:]
            let username = user["username"] as? String ?? user["handle"] as? String ?? "user"
            let display = user["displayName"] as? String ?? user["display_name"] as? String ?? username
            let rawURL = row["videoURL"] as? String ?? row["videoUrl"] as? String ?? row["url"] as? String ?? "/api/videos/\(id)/file"
            let url = URL(string: rawURL)?.scheme == nil ? baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + (rawURL.hasPrefix("/") ? rawURL : "/\(rawURL)") : rawURL
            let caption = row["caption"] as? String ?? ""
            let likes = row["likes"] as? Int ?? 0
            let comments = row["comments"] as? Int ?? 0
            var clip = FeedClip(id: abs(id.hashValue % 2_000_000_000), creator: display, handle: "@\(username)", caption: caption, tags: "", song: "original audio · \(username)", likes: String(likes), comments: String(comments), views: row["views"] as? Int ?? 0, accent: .purple, videoURL: url, symbol: "person")
            clip.initiallyLiked = row["likedByMe"] as? Bool ?? false
            clip.initiallySaved = row["savedByMe"] as? Bool ?? false
            return clip
        }
    }

    static func uploadVideo(fileURL: URL, caption: String) async throws {
        let video = try Data(contentsOf: fileURL)
        let boundary = "LerizBoundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n\(caption)\r\n")
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"video\"; filename=\"leriz-upload.mp4\"\r\nContent-Type: video/mp4\r\n\r\n")
        body.append(video)
        append("\r\n--\(boundary)--\r\n")
        _ = try await request("api/videos", method: "POST", body: body, contentType: "multipart/form-data; boundary=\(boundary)")
    }

    static func toggleLike(videoID: String) async throws -> [String: Any] {
        let (data, _) = try await request("api/videos/\(videoID)/like", method: "POST", body: Data("{}".utf8))
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
    static func toggleSave(videoID: String) async throws -> [String: Any] {
        let (data, _) = try await request("api/videos/\(videoID)/save", method: "POST", body: Data("{}".utf8))
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
    static func fetchComments(videoID: String) async throws -> [[String: Any]] {
        let (data, _) = try await request("api/videos/\(videoID)/comments")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["comments"] as? [[String: Any]] ?? []
    }
    static func postComment(videoID: String, text: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["text": text])
        _ = try await request("api/videos/\(videoID)/comments", method: "POST", body: body)
    }
    static func follow(username: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["username": username])
        _ = try await request("api/users/\(username)/follow", method: "POST", body: body)
    }
}

@main
struct LerizApp: App {
    var body: some Scene {
        WindowGroup {
            LerizLaunchView()
                .preferredColorScheme(.dark)
        }
    }
}

struct FeedClip: Identifiable {
    let id: Int
    let creator: String
    let handle: String
    let caption: String
    let tags: String
    let song: String
    let likes: String
    let comments: String
    let views: Int
    let accent: Color
    let videoURL: String
    let symbol: String
    var initiallyLiked = false
    var initiallySaved = false

    var serverID: String? {
        guard let url = URL(string: videoURL) else { return nil }
        let parts = url.pathComponents
        guard let index = parts.firstIndex(of: "videos"), parts.indices.contains(index + 1) else { return nil }
        return parts[index + 1]
    }

    // The feed starts empty and is populated only by videos returned by the Leriz backend.
    static let samples: [FeedClip] = []
}


struct LerizLaunchView: View {
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var showWelcome = false
    @State private var enterApp = false
    @State private var authError = ""
    @AppStorage("lerizAuthToken") private var authToken = ""

    var body: some View {
        ZStack {
            if enterApp {
                LoopFeedView()
                    .transition(.opacity)
            } else if showWelcome {
                welcomeScreen
                    .transition(.opacity)
            } else {
                authScreen
                    .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: authToken) { value in
            if value.isEmpty { enterApp = false; showWelcome = false; isSignUp = false; password = "" }
        }
        .preferredColorScheme(.dark)
    }

    private var authScreen: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.04, blue: 0.22), .black, Color(red: 0.02, green: 0.13, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle().fill(.purple.opacity(0.20)).frame(width: 260).blur(radius: 75).offset(x: 130, y: -270)
            Circle().fill(.cyan.opacity(0.14)).frame(width: 250).blur(radius: 80).offset(x: -150, y: 250)
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                ZStack {
                    RoundedRectangle(cornerRadius: 25).fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 76, height: 76)
                    Image(systemName: "infinity").font(.system(size: 42, weight: .medium)).foregroundStyle(.white)
                }
                .shadow(color: .purple.opacity(0.35), radius: 25, y: 8)
                Text("Leriz").font(.system(size: 38, weight: .black, design: .rounded)).tracking(-1.5).padding(.top, 15)
                Text("Your world. In motion.").font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.60)).padding(.top, 5)
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 0) {
                        authModeButton("Log in", selected: !isSignUp) { withAnimation(.easeInOut(duration: 0.22)) { isSignUp = false } }
                        authModeButton("Sign up", selected: isSignUp) { withAnimation(.easeInOut(duration: 0.22)) { isSignUp = true } }
                    }
                    if isSignUp {
                        authField(title: "Username", placeholder: "Choose a username", text: $username, symbol: "person")
                    }
                    authField(title: "Email", placeholder: "you@example.com", text: $email, symbol: "envelope", isEmail: true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PASSWORD").font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(.white.opacity(0.58))
                        HStack(spacing: 11) {
                            Image(systemName: "lock").foregroundStyle(.white.opacity(0.55)).frame(width: 20)
                            SecureField("Enter your password", text: $password).textContentType(isSignUp ? .newPassword : .password).autocorrectionDisabled()
                        }
                        .padding(.horizontal, 15).frame(height: 54)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.10), lineWidth: 1))
                    }
                    Button(action: startDemo) {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView().tint(.white)
                                Text("Getting things ready…")
                            } else {
                                Text(isSignUp ? "Create account" : "Log in")
                                Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(LinearGradient(colors: [.cyan.opacity(0.95), .purple, .pink.opacity(0.95)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isLoading)
                    if !authError.isEmpty {
                        Text(authError)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                }
                .padding(22)
                .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.10), lineWidth: 1))
                .padding(.horizontal, 22).padding(.top, 34)
                Spacer(minLength: 30)
                Text("MAKE EVERY MOMENT YOURS")
                    .font(.system(size: 10, weight: .bold)).tracking(2.2).foregroundStyle(.white.opacity(0.35)).padding(.bottom, 20)
            }
        }
    }

    private var welcomeScreen: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.02, blue: 0.13), .black, Color(red: 0.01, green: 0.12, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(.purple.opacity(0.28)).frame(width: 300).blur(radius: 80).offset(x: -90, y: -120)
            Circle().fill(.cyan.opacity(0.24)).frame(width: 280).blur(radius: 80).offset(x: 120, y: 160)
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32).fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 108, height: 108)
                    Image(systemName: "infinity").font(.system(size: 61, weight: .medium)).foregroundStyle(.white)
                }
                .shadow(color: .purple.opacity(0.45), radius: 35, y: 10)
                Text("Welcome to Leriz")
                    .font(.system(size: 34, weight: .black, design: .rounded)).tracking(-1).multilineTextAlignment(.center)
                Text("A whole world of videos is waiting for you.")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.66)).multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(.cyan)
                    Text("Find your next favorite moment").foregroundStyle(.white.opacity(0.8))
                }.font(.system(size: 13, weight: .medium)).padding(.top, 5)
                ProgressView().tint(.white).padding(.top, 25)
            }
            .padding(.horizontal, 30)
        }
    }

    private func authModeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .bold))
                .foregroundStyle(selected ? .white : .white.opacity(0.48))
                .frame(maxWidth: .infinity).frame(height: 43)
                .background {
                    if selected { RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12)) }
                }
        }.buttonStyle(.plain)
    }

    private func authField(title: String, placeholder: String, text: Binding<String>, symbol: String, isEmail: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.2).foregroundStyle(.white.opacity(0.58))
            HStack(spacing: 11) {
                Image(systemName: symbol).foregroundStyle(.white.opacity(0.55)).frame(width: 20)
                TextField(placeholder, text: text)
                    .keyboardType(isEmail ? .emailAddress : .default)
                    .textContentType(isEmail ? .emailAddress : .username)
                    .textInputAutocapitalization(isEmail ? .never : .words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 15).frame(height: 54)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.10), lineWidth: 1))
        }
    }

    private func startDemo() {
        guard !isLoading else { return }
        authError = ""
        isLoading = true
        Task { await authenticateWithServer() }
    }

    @MainActor
    private func authenticateWithServer() async {
        let config = LerizServerConfiguration.current
        guard let baseURL = URL(string: config.baseURL) else {
            isLoading = false
            authError = "The server URL in server.json is invalid."
            return
        }

        var payload: [String: String] = ["password": password]
        let endpoint: String
        if isSignUp {
            payload["username"] = username.trimmingCharacters(in: .whitespacesAndNewlines)
            payload["displayName"] = username.trimmingCharacters(in: .whitespacesAndNewlines)
            payload["email"] = email.trimmingCharacters(in: .whitespacesAndNewlines)
            endpoint = "api/auth/register"
        } else {
            payload["email"] = email.trimmingCharacters(in: .whitespacesAndNewlines)
            endpoint = "api/auth/login"
        }

        guard !payload["email", default: ""].isEmpty,
              !password.isEmpty,
              (!isSignUp || !payload["username", default: ""].isEmpty) else {
            isLoading = false
            authError = isSignUp ? "Enter a username, email, and password." : "Enter your email and password."
            return
        }

        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NSError(domain: "LerizServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "The server returned an invalid response."])
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            guard (200...299).contains(http.statusCode), json["ok"] as? Bool == true,
                  let token = json["token"] as? String, !token.isEmpty else {
                let message = json["error"] as? String ?? json["message"] as? String ?? "Request failed (HTTP \\(http.statusCode)). Check your details and try again."
                isLoading = false
                authError = message
                return
            }

            authToken = token
            if isSignUp {
                UserDefaults.standard.set(username.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "lerizUsername")
            } else {
                let user = json["user"] as? [String: Any] ?? [:]
                let serverUsername = user["username"] as? String ?? user["handle"] as? String ?? ""
                if !serverUsername.isEmpty { UserDefaults.standard.set(serverUsername, forKey: "lerizUsername") }
                else if let emailName = email.split(separator: "@").first { UserDefaults.standard.set(String(emailName), forKey: "lerizUsername") }
            }
            withAnimation(.easeInOut(duration: 0.65)) {
                isLoading = false
                showWelcome = true
            }
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeInOut(duration: 1.0)) {
                enterApp = true
            }
        } catch {
            isLoading = false
            authError = "Cannot connect to \\(config.serverName). Check that the backend and ngrok are running. \\(error.localizedDescription)"
        }
    }
}

struct LoopFeedView: View {
    @State private var clips: [FeedClip] = []
    @State private var feedLoading = true
    @State private var feedError = ""
    @AppStorage("lerizUsername") private var currentUsername = ""
    @AppStorage("lerizAuthToken") private var authToken = ""
    @State private var selectedClip = 0
    @State private var showCreate = false
    @State private var likedIDs: Set<Int> = []
    @State private var savedIDs: Set<Int> = []
    @State private var selectedTab = "For You"
    @Namespace private var feedTabUnderline
    @State private var showComments = false
    @State private var showSearch = false
    @State private var showProfile = false
    @State private var selectedProfileClip: FeedClip? = nil
    @State private var showInbox = false
    @State private var showShare = false
    @State private var selectedSongClip: FeedClip? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if feedLoading {
                VStack(spacing: 12) { ProgressView().tint(.white); Text("Loading videos…").font(.subheadline).foregroundStyle(.secondary) }
            } else if clips.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "video.slash").font(.system(size: 48, weight: .light)).foregroundStyle(.white.opacity(0.6))
                    Text("No videos available").font(.title3.bold()).foregroundStyle(.white)
                    Text(feedError.isEmpty ? "Be the first to upload a video." : feedError).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 34)
                    Button { showCreate = true } label: { Label("Upload a video", systemImage: "plus").font(.system(size: 15, weight: .bold)).padding(.horizontal, 20).padding(.vertical, 12).background(.white.opacity(0.12), in: Capsule()) }
                }
            } else {
            GeometryReader { geometry in
                TabView(selection: $selectedClip) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        ClipPage(
                            clip: clip,
                            isActive: selectedClip == index,
                            isLiked: likedIDs.contains(clip.id),
                            isSaved: savedIDs.contains(clip.id),
                            onLike: { toggleLike(clip.id) },
                            onSave: { toggleSave(clip.id) },
                            onComments: { showComments = true },
                            onShare: { showShare = true },
                            onProfile: { selectedProfileClip = clip },
                            onSong: { selectedSongClip = clip },
                            onFollow: {
                                let username = clip.handle.hasPrefix("@") ? String(clip.handle.dropFirst()) : clip.handle
                                Task { do { try await LerizAPI.follow(username: username) } catch { await MainActor.run { feedError = "Follow failed: \(error.localizedDescription)" } } }
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .rotationEffect(.degrees(-90))
                        .tag(index)
                    }
                }
                .frame(width: geometry.size.height, height: geometry.size.width)
                .rotationEffect(.degrees(90))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                .overlay(alignment: .top) { topBar }
                .overlay(alignment: .bottom) { bottomBar }
            }
            .ignoresSafeArea()
            }
        }
        .task { await loadFeed() }
        .onChange(of: selectedTab) { value in Task { await loadFeed(mode: value == "Following" ? "following" : "forYou") } }
        .sheet(isPresented: $showComments) { if !clips.isEmpty { CommentsSheet(clip: clips[selectedClip]) } }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .sheet(isPresented: $showSearch) {
            SearchSheet(clips: clips) { chosenClip in
                if let index = clips.firstIndex(where: { $0.id == chosenClip.id }) {
                    selectedClip = index
                }
            }
        }
        .fullScreenCover(item: $selectedProfileClip) { profileClip in
            ProfileSheet(clip: profileClip)
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileSheet()
        }
        .fullScreenCover(isPresented: $showCreate) {
            CreateVideoPage { caption, mediaURL in
                Task {
                    do {
                        try await LerizAPI.uploadVideo(fileURL: mediaURL, caption: caption)
                        await loadFeed()
                        await MainActor.run {
                            selectedClip = 0
                            showCreate = false
                        }
                    } catch {
                        await MainActor.run { feedError = "Upload failed: \(error.localizedDescription)" }
                    }
                }
            }
        }
        .sheet(isPresented: $showInbox) { InboxSheet() }
        .sheet(isPresented: $showShare) { ShareSheet(clip: clips[selectedClip]) }
        .sheet(item: $selectedSongClip) { songClip in
            SongDetailSheet(clip: songClip, clips: clips) { chosenClip in
                if let index = clips.firstIndex(where: { $0.id == chosenClip.id }) { selectedClip = index }
            }
        }
    }

    @MainActor
    private func loadFeed(mode: String = "forYou") async {
        feedLoading = true
        do {
            clips = try await LerizAPI.fetchFeed(mode: mode)
            likedIDs = Set(clips.filter { $0.initiallyLiked }.map(\.id))
            savedIDs = Set(clips.filter { $0.initiallySaved }.map(\.id))
            selectedClip = min(selectedClip, max(0, clips.count - 1))
            feedError = ""
        } catch {
            clips = []
            feedError = "Could not load videos. Check your connection and try again."
        }
        feedLoading = false
    }

    private var topBar: some View {
        HStack(spacing: 15) {
            HStack(spacing: 5) {
                Image(systemName: "infinity")
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Leriz")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .tracking(-1.2)
            }
            Spacer(minLength: 2)
            feedTabButton("Following")
            feedTabButton("For You")
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .regular)).foregroundStyle(.white)
            }
            .accessibilityLabel("Search videos")
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .padding(.bottom, 15)
        .background(LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .top, endPoint: .bottom))
    }

    private func feedTabButton(_ title: String) -> some View {
        let selected = selectedTab == title
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                selectedTab = title
            }
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? .white : .white.opacity(0.68))
                    .offset(y: selected ? -2 : 2)
                ZStack {
                    Capsule().fill(Color.clear).frame(width: 28, height: 3)
                    if selected {
                        Capsule().fill(Color.cyan).frame(width: 28, height: 3)
                            .matchedGeometryEffect(id: "feed-tab-underline", in: feedTabUnderline)
                    }
                }
            }
            .frame(minHeight: 25)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack {
            navButton("house", title: "Home", selected: true) {}
            Spacer()
            navButton("safari", title: "Discover", selected: false) { showSearch = true }
            Spacer()
            Button { showCreate = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(LinearGradient(colors: [.cyan, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 43, height: 31)
                    Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundStyle(.white)
                }
            }
            Spacer()
            navButton("text.bubble", title: "Inbox", selected: false) { showInbox = true }
            Spacer()
            navButton("person.crop.circle", title: "Profile", selected: false) { selectedProfileClip = nil; showProfile = true }
        }
        .padding(.horizontal, 24)
        .padding(.top, 13)
        .padding(.bottom, 30)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.88), .black], startPoint: .top, endPoint: .bottom))
    }

    private func navButton(_ symbol: String, title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 21, weight: .regular))
                Text(title).font(.system(size: 10, weight: selected ? .bold : .medium))
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.68))
        }
    }

    private func toggleLike(_ id: Int) {
        if likedIDs.contains(id) { likedIDs.remove(id) } else { likedIDs.insert(id) }
        guard let videoID = serverID(for: id) else { return }
        Task {
            do {
                let result = try await LerizAPI.toggleLike(videoID: videoID)
                await MainActor.run {
                    if let liked = result["liked"] as? Bool {
                        if liked { likedIDs.insert(id) } else { likedIDs.remove(id) }
                    }
                    if let count = result["likes"] as? Int, let index = clips.firstIndex(where: { $0.id == id }) { clips[index] = withLikes(clips[index], count: count) }
                }
            } catch { await MainActor.run { feedError = error.localizedDescription; likedIDs.remove(id) } }
        }
    }

    private func toggleSave(_ id: Int) {
        if savedIDs.contains(id) { savedIDs.remove(id) } else { savedIDs.insert(id) }
        guard let videoID = serverID(for: id) else { return }
        Task {
            do {
                let result = try await LerizAPI.toggleSave(videoID: videoID)
                await MainActor.run {
                    if let saved = result["saved"] as? Bool {
                        if saved { savedIDs.insert(id) } else { savedIDs.remove(id) }
                    }
                }
            } catch { await MainActor.run { feedError = error.localizedDescription; savedIDs.remove(id) } }
        }
    }

    private func withLikes(_ clip: FeedClip, count: Int) -> FeedClip {
        var updated = FeedClip(id: clip.id, creator: clip.creator, handle: clip.handle, caption: clip.caption, tags: clip.tags, song: clip.song, likes: String(count), comments: clip.comments, views: clip.views, accent: clip.accent, videoURL: clip.videoURL, symbol: clip.symbol)
        updated.initiallyLiked = clip.initiallyLiked
        updated.initiallySaved = clip.initiallySaved
        return updated
    }

    private func serverID(for id: Int) -> String? {
        guard let clip = clips.first(where: { $0.id == id }),
              let url = URL(string: clip.videoURL) else { return nil }
        let parts = url.pathComponents
        guard let apiIndex = parts.firstIndex(of: "videos"), parts.indices.contains(apiIndex + 1) else { return nil }
        return parts[apiIndex + 1]
    }
}

struct ClipPage: View {
    let clip: FeedClip
    let isActive: Bool
    let isLiked: Bool
    let isSaved: Bool
    let onLike: () -> Void
    let onSave: () -> Void
    let onComments: () -> Void
    let onShare: () -> Void
    let onProfile: () -> Void
    let onSong: () -> Void
    let onFollow: () -> Void
    @State private var player = AVPlayer()
    @State private var isPlaying = true
    @State private var videoFailed = false
    @State private var isFollowing = false
    @State private var isMuted = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [clip.accent.opacity(0.72), Color.black, clip.accent.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            if !videoFailed, let url = URL(string: clip.videoURL) {
                PlayerSurface(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        player.isMuted = false
                        if isActive { player.play() }
                    }
                    .onChange(of: isActive) { active in
                        if active { player.play(); isPlaying = true } else { player.pause() }
                    }
                    .onDisappear { player.pause() }
                    .overlay {
                        Button {
                            if isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { isPlaying.toggle() }
                        } label: {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
            }
            LinearGradient(colors: [.black.opacity(0.22), .clear, .clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 8) {
                            Button(action: onProfile) {
                                ZStack {
                                    Circle().fill(clip.accent).frame(width: 38, height: 38)
                                    Image(systemName: clip.symbol).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            Text(clip.creator).font(.system(size: 15, weight: .bold))
                            Text("·").foregroundStyle(.white.opacity(0.6))
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) { isFollowing.toggle() }
                                onFollow()
                            } label: {
                                Text(isFollowing ? "Following" : "Follow")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(isFollowing ? .white.opacity(0.8) : .cyan)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(clip.caption)
                            .font(.system(size: 14, weight: .medium))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(clip.tags).font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.94))
                        HStack(spacing: 7) {
                            Image(systemName: "music.note")
                            Text(clip.song).lineLimit(1)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.top, 2)
                    }
                    .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    VStack(spacing: 20) {
                        ZStack(alignment: .bottom) {
                            Button(action: onProfile) {
                                ZStack {
                                    Circle().fill(clip.accent).frame(width: 46, height: 46)
                                    Image(systemName: clip.symbol).font(.system(size: 21, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 46)
                                }
                            }
                            .buttonStyle(.plain)
                            if !isFollowing {
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) { isFollowing = true }
                                    onFollow()
                                } label: {
                                    ZStack {
                                        Circle().fill(Color.pink).frame(width: 21, height: 21)
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundStyle(.white)
                                    }
                                    .overlay(Circle().stroke(Color.black.opacity(0.75), lineWidth: 1.5))
                                    .scaleEffect(isFollowing ? 0.2 : 1)
                                    .opacity(isFollowing ? 0 : 1)
                                }
                                .buttonStyle(.plain)
                                .offset(y: 8)
                                .transition(.scale(scale: 0.35, anchor: .center).combined(with: .opacity))
                                .accessibilityLabel("Follow creator")
                            }
                        }
                        actionButton(isLiked ? "heart.fill" : "heart", value: clip.likes, color: .white, gradient: isLiked, action: onLike)
                        actionButton("text.bubble", value: clip.comments, color: .white, action: onComments)
                        actionButton(isSaved ? "bookmark.fill" : "bookmark", value: isSaved ? "Saved" : "Save", color: isSaved ? Color(red: 1, green: 0.78, blue: 0.16) : .white, action: onSave)
                        actionButton("arrowshape.turn.up.right", value: "Share", color: .white, action: onShare)
                        Button(action: onSong) {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.16)).frame(width: 40, height: 40)
                                Image(systemName: "opticaldisc").font(.system(size: 27, weight: .regular)).foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open sound page")
                    }
                    .frame(width: 54)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 112)
            }

            if !isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 2)
                    .frame(width: 76, height: 76)
                    .background(.black.opacity(0.48), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .background(Color.black)
        .onAppear { if isActive { player.play() } }
    }

    private func actionButton(_ symbol: String, value: String, color: Color, gradient: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if gradient {
                    Image(systemName: symbol)
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(LinearGradient(colors: [.pink, .purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .black.opacity(0.25), radius: 4)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(color)
                        .shadow(color: .black.opacity(0.25), radius: 4)
                }
                Text(value).font(.system(size: 10, weight: .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
            }
        }
    }
}

struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PlayerView, context: Context) { uiView.playerLayer.player = player }
}

final class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct CommentsSheet: View {
    let clip: FeedClip
    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var posted: [String] = []
    @State private var commentIDs: [String] = []
    @State private var commentAuthors: [String] = []
    @AppStorage("lerizUsername") private var currentUsername = ""
    @State private var commentError = ""
    @State private var showEmojiPicker = false
    @State private var likedComments: Set<Int> = []
    @State private var previewPlayer = AVPlayer()
    @FocusState private var commentFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    PlayerSurface(player: previewPlayer)
                        .frame(width: 92, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(clip.creator).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble").foregroundStyle(.cyan)
                            Text("\\(clip.comments) comments").font(.system(size: 12, weight: .medium))
                        }.foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                            .padding(8).background(Color.white.opacity(0.08), in: Circle())
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .onAppear {
                    if let url = URL(string: clip.videoURL) {
                        previewPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
                        previewPlayer.isMuted = true
                        previewPlayer.play()
                    }
                    Task { await loadComments() }
                }
                .onDisappear { previewPlayer.pause() }

                Divider().overlay(Color.white.opacity(0.08))

                ScrollView {
                    LazyVStack(spacing: 2) {
                        if posted.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "text.bubble").font(.system(size: 30)).foregroundStyle(.secondary)
                                Text(commentError.isEmpty ? "No comments yet" : commentError).font(.subheadline).foregroundStyle(.secondary)
                                Text("Be the first to comment.").font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(.top, 36)
                        }
                        ForEach(Array(posted.enumerated()), id: \.offset) { index, text in
                            HStack(alignment: .top, spacing: 11) {
                                Circle().fill(LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 38, height: 38)
                                    .overlay(Image(systemName: "person").font(.system(size: 15)).foregroundStyle(.white))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(index < commentAuthors.count ? commentAuthors[index] : "user")
                                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                                    Text(text).font(.system(size: 14))
                                    HStack(spacing: 14) {
                                        Text("2h").font(.caption).foregroundStyle(.secondary)
                                        Button("Reply") {
                                            let author = index < commentAuthors.count ? commentAuthors[index] : "user"
                                            comment = "@\(author) "
                                            commentFieldFocused = true
                                        }
                                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                    }.padding(.top, 2)
                                }
                                Spacer(minLength: 8)
                                Button { if likedComments.contains(index) { likedComments.remove(index) } else { likedComments.insert(index) } } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "heart")
                                            .font(.system(size: 15))
                                            .foregroundStyle(likedComments.contains(index) ? AnyShapeStyle(LinearGradient(colors: [.pink, .purple, .orange], startPoint: .bottomLeading, endPoint: .topTrailing)) : AnyShapeStyle(Color.white.opacity(0.68)))
                                        Text(likedComments.contains(index) ? "1" : "").font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 17)
                            .padding(.vertical, 13)
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))
                HStack(spacing: 10) {
                    Circle().fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 35, height: 35)
                        .overlay(Image(systemName: "person").font(.system(size: 14)).foregroundStyle(.white))
                    HStack(spacing: 8) {
                        TextField("Add a comment…", text: $comment, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(1...4)
                            .focused($commentFieldFocused)
                            .submitLabel(.send)
                            .onSubmit(postComment)
                        if !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: postComment) {
                                Image(systemName: "arrow.up.circle")
                                    .font(.system(size: 27))
                                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .leading, endPoint: .trailing))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
                    Menu {
                        ForEach(["😀","😂","🥹","😍","🔥","❤️","😭","👏","✨","🙏","💀","🥰"], id: \.self) { emoji in
                            Button(emoji) { comment.append(emoji) }
                        }
                    } label: {
                        Image(systemName: "face.smiling").font(.system(size: 21)).foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial)
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.secondary).padding(7).background(Color.white.opacity(0.08), in: Circle()) }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private func loadComments() async {
        guard let videoID = clip.serverID else { commentError = "Comments are unavailable for this video."; return }
        do {
            let rows = try await LerizAPI.fetchComments(videoID: videoID)
            await MainActor.run {
                posted = rows.compactMap { $0["text"] as? String }
                commentIDs = rows.compactMap { $0["id"].map { String(describing: $0) } }
                commentAuthors = rows.map { row in
                    let user = row["user"] as? [String: Any] ?? [:]
                    return user["username"] as? String ?? row["username"] as? String ?? "user"
                }
                commentError = ""
            }
        } catch {
            await MainActor.run { commentError = "Could not load comments. Try again." }
        }
    }

    private func postComment() {
        let clean = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let videoID = clip.serverID else { return }
        Task {
            do {
                try await LerizAPI.postComment(videoID: videoID, text: clean)
                await MainActor.run { posted.insert(clean, at: 0); commentIDs.insert(UUID().uuidString, at: 0); commentAuthors.insert(currentUsername.isEmpty ? "user" : currentUsername, at: 0); comment = ""; commentFieldFocused = false }
            } catch {
                await MainActor.run { commentError = "Comment failed: \(error.localizedDescription)" }
            }
        }
    }
}

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var isTrendingSelected = false
    @State private var showTrendingPage = false
    @State private var selectedTrendToOpen: String? = nil
    let clips: [FeedClip]
    let onSelectClip: (FeedClip) -> Void
    private let trends = ["#loopchallenge", "#travelcore", "#oddlysatisfying"]

    private var matchingClips: [FeedClip] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return clips }
        return clips.filter {
            $0.creator.localizedCaseInsensitiveContains(term) ||
            $0.handle.localizedCaseInsensitiveContains(term) ||
            $0.caption.localizedCaseInsensitiveContains(term) ||
            $0.tags.localizedCaseInsensitiveContains(term) ||
            $0.song.localizedCaseInsensitiveContains(term)
        }
    }

    private var popularClips: [FeedClip] {
        clips.sorted { $0.views > $1.views }
    }

    private func gridOrder(_ ranked: [FeedClip]) -> [FeedClip] {
        stride(from: 0, to: ranked.count, by: 3).flatMap { start in
            Array(ranked[start..<min(start + 3, ranked.count)].reversed())
        }
    }

    private let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search videos, creators, sounds, tags", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack {
                            Text("VIDEO RESULTS").font(.caption.bold()).foregroundStyle(.secondary).tracking(1.4)
                            Spacer()
                            Text("\(matchingClips.count)").font(.caption).foregroundStyle(.secondary)
                        }
                        if matchingClips.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "video.slash").font(.system(size: 30)).foregroundStyle(.secondary)
                                Text("No matching videos").font(.headline)
                                Text("Try a creator name, caption, sound, or hashtag.")
                                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 35)
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(gridOrder(matchingClips.sorted { $0.views > $1.views })) { clip in
                                    Button {
                                        onSelectClip(clip)
                                        dismiss()
                                    } label: {
                                        VideoPreviewTile(clip: clip)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        Button {
                            isTrendingSelected = true
                            showTrendingPage = true
                        } label: {
                            HStack(spacing: 7) {
                                Text("TRENDING NOW").font(.caption.bold()).tracking(1.5)
                                Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(isTrendingSelected ? Color.blue : Color.secondary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        ForEach(trends, id: \.self) { tag in
                            Button {
                                selectedTrendToOpen = tag
                                showTrendingPage = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.pink)
                                    Text(tag).fontWeight(.semibold).foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }

                        Text("POPULAR VIDEOS").font(.caption.bold()).foregroundStyle(.secondary).tracking(1.5).padding(.top, 4)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(gridOrder(popularClips)) { clip in
                                Button {
                                    onSelectClip(clip)
                                    dismiss()
                                } label: {
                                    VideoPreviewTile(clip: clip)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showTrendingPage) {
                TrendingVideosPage(clips: clips, initialTrend: selectedTrendToOpen, onSelectClip: { chosen in
                    onSelectClip(chosen)
                    dismiss()
                })
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TrendingVideosPage: View {
    @Environment(\.dismiss) private var dismiss
    let clips: [FeedClip]
    let onSelectClip: (FeedClip) -> Void
    @State private var selectedTrend: String? = nil
    private let trends = ["#loopchallenge", "#travelcore", "#oddlysatisfying"]

    init(clips: [FeedClip], initialTrend: String? = nil, onSelectClip: @escaping (FeedClip) -> Void) {
        self.clips = clips
        self.onSelectClip = onSelectClip
        _selectedTrend = State(initialValue: initialTrend)
    }
    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    private var trendClips: [FeedClip] {
        guard let selectedTrend else { return clips.sorted { $0.views > $1.views } }
        let matches = clips.filter { $0.tags.localizedCaseInsensitiveContains(selectedTrend) }
        return (matches.isEmpty ? clips : matches).sorted { $0.views > $1.views }
    }

    private var gridClips: [FeedClip] {
        let sorted = trendClips
        return stride(from: 0, to: sorted.count, by: 3).flatMap { start in
            Array(sorted[start..<min(start + 3, sorted.count)].reversed())
        }
    }

    var body: some View {
        ScrollView {
            if let selectedTrend {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 58, height: 58)
                            .background(Color.white.opacity(0.08))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selectedTrend).font(.system(size: 21, weight: .black))
                            Text("Trending videos · ranked by views").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Text("\(trendClips.count) videos").font(.caption.bold()).foregroundStyle(.secondary)
                }
                .padding(12)
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(gridClips) { clip in
                        Button {
                            onSelectClip(clip)
                            dismiss()
                        } label: {
                            VideoPreviewTile(clip: clip)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                .clipped()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("TOP TRENDS").font(.caption.bold()).tracking(1.5).foregroundStyle(.secondary)
                    ForEach(Array(trends.enumerated()), id: \.element) { index, trend in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTrend = trend }
                        } label: {
                            HStack(spacing: 12) {
                                Text("#\(index + 1)").font(.system(size: 14, weight: .black)).foregroundStyle(index == 0 ? .yellow : .secondary).frame(width: 28)
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 21, weight: .bold)).foregroundStyle(.pink)
                                    .frame(width: 48, height: 58).background(Color.white.opacity(0.06))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(trend).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    Text("Tap to explore videos").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("POPULAR VIDEOS").font(.caption.bold()).tracking(1.5).foregroundStyle(.secondary).padding(.top, 10)
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(gridClips) { clip in
                            Button {
                                onSelectClip(clip)
                                dismiss()
                            } label: {
                                VideoPreviewTile(clip: clip)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                    .clipped()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(selectedTrend == nil ? "Trending now" : "Trend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if selectedTrend != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button { selectedTrend = nil } label: { Image(systemName: "chevron.left").fontWeight(.semibold) }
                }
            }
        }
    }
}
struct VideoPreviewTile: View {
    let clip: FeedClip
    @State private var player = AVPlayer()
    @State private var frameIndex = 0
    private let frameCount = 6

    var body: some View {
        PlayerSurface(player: player)
            .frame(maxWidth: .infinity)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .background(clip.accent.gradient)
            .clipped()
            .onAppear {
                guard let url = URL(string: clip.videoURL) else { return }
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
                player.isMuted = true
                player.pause()
                seekToPreviewFrame()
            }
            .onReceive(Timer.publish(every: 1.0 / 3.0, on: .main, in: .common).autoconnect()) { _ in
                guard player.currentItem != nil else { return }
                frameIndex = (frameIndex + 1) % frameCount
                seekToPreviewFrame()
            }
            .onDisappear { player.pause() }
    }

    private func seekToPreviewFrame() {
        let seconds = Double(frameIndex) / 3.0
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}
struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    var clip: FeedClip? = nil
    @State private var selectedTab = 0
    @State private var showEdit = false
    @State private var showProfileMenu = false
    @State private var showNotifications = false
    @State private var showSavedVideos = false
    @State private var selectedAvatar: PhotosPickerItem?
    @AppStorage("lerizProfileImageData") private var profileImageData = ""
    @AppStorage("lerizAuthToken") private var authToken = ""
    @AppStorage("lerizUsername") private var currentUsername = ""
    @AppStorage("lerizDisplayName") private var displayName = ""
    @AppStorage("lerizBio") private var profileBio = "Capture your world, your way."
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedAvatar, matching: .images) {
                            Group {
                                if let data = Data(base64Encoded: profileImageData), let image = UIImage(data: data) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else {
                                    Circle().fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 40)).foregroundStyle(.white))
                                }
                            }
                            .frame(width: 88, height: 88).clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(clip?.creator ?? (displayName.isEmpty ? (currentUsername.isEmpty ? "Leriz user" : currentUsername) : displayName)).font(.title3.bold())
                            Text(clip?.handle ?? "@\(currentUsername.isEmpty ? "user" : currentUsername)").font(.subheadline).foregroundStyle(.secondary)
                            Text(clip == nil ? "Your creator profile" : "Creator on Leriz").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }.padding(.horizontal, 18).padding(.top, 15)
                    HStack {
                        stat("0", "Following")
                        stat("0", "Followers")
                        stat("0", "Likes")
                    }
                    HStack(spacing: 10) {
                        Button { showEdit = true } label: { Text("Edit profile").font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(12).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 9)) }
                        Button {} label: { Image(systemName: "person.badge.plus").frame(width: 46, height: 42).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 9)) }
                    }.padding(.horizontal, 18)
                    Text(profileBio).font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18)
                    HStack(spacing: 0) {
                        tab("square.grid.2x2", 0)
                        tab("heart", 1)
                    }.padding(.top, 5)
                    Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5)
                    VStack(spacing: 10) {
                        Image(systemName: selectedTab == 0 ? "video" : "heart").font(.system(size: 34)).foregroundStyle(.secondary)
                        Text(selectedTab == 0 ? "Your videos will appear here" : "Videos you like will appear here").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 60)
                }
            }.background(Color.black)
            .navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left").fontWeight(.semibold) } }
                ToolbarItem(placement: .topBarTrailing) { Button { showProfileMenu = true } label: { Image(systemName: "line.3.horizontal") } }
            }
            .confirmationDialog("Profile menu", isPresented: $showProfileMenu, titleVisibility: .visible) {
                Button("Settings") { showEdit = true }
                Button("Saved videos") { showSavedVideos = true }
                Button("Notifications") { showNotifications = true }
                Button("Log out", role: .destructive) {
                    authToken = ""
                    UserDefaults.standard.removeObject(forKey: "lerizUsername")
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showEdit) { EditProfileDemo() }
            .sheet(isPresented: $showNotifications) { InboxSheet() }
            .sheet(isPresented: $showSavedVideos) { SavedVideosSheet() }
            .onChange(of: selectedAvatar) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpeg = image.jpegData(compressionQuality: 0.82) {
                        await MainActor.run { profileImageData = jpeg.base64EncodedString() }
                    }
                }
            }
        }.preferredColorScheme(.dark)
    }
    private func stat(_ n: String, _ label: String) -> some View {
        VStack(spacing: 4) { Text(n).font(.system(size: 18, weight: .bold)); Text(label).font(.system(size: 12)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
    private func tab(_ icon: String, _ index: Int) -> some View {
        Button { selectedTab = index } label: {
            VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 18)); Rectangle().fill(selectedTab == index ? Color.white : .clear).frame(height: 2) }
                .frame(maxWidth: .infinity).foregroundStyle(selectedTab == index ? .white : .secondary)
        }
    }
}

struct EditProfileDemo: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lerizDisplayName") private var name = ""
    @AppStorage("lerizUsername") private var username = ""
    @AppStorage("lerizBio") private var bio = "Capture your world, your way."
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") { TextField("Name", text: $name); TextField("Username", text: $username); TextField("Bio", text: $bio, axis: .vertical) }
                Section { Text("Your profile details are saved on this device.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

struct InboxSheet: View {
    @State private var notifications: [[String: Any]] = []
    @State private var loadError = ""
    var body: some View {
        NavigationStack {
            Group {
                if notifications.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bell").font(.system(size: 34)).foregroundStyle(.secondary)
                        Text(loadError.isEmpty ? "No notifications" : loadError).font(.headline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(notifications.indices, id: \.self) { index in
                        let row = notifications[index]
                        HStack(spacing: 12) {
                            Circle().fill(.white.opacity(0.1)).frame(width: 42, height: 42).overlay(Image(systemName: "bell").foregroundStyle(.cyan))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row["type"] as? String ?? "Activity").fontWeight(.semibold)
                                Text((row["actor"] as? [String: Any])?["username"] as? String ?? "Leriz user").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }.scrollContentBackground(.hidden)
                }
            }
            .background(Color.black)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                do {
                    let (data, _) = try await LerizAPI.request("api/notifications")
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    notifications = json["notifications"] as? [[String: Any]] ?? []
                    if notifications.isEmpty { loadError = "" }
                } catch { loadError = "Could not load notifications." }
            }
        }.preferredColorScheme(.dark)
    }
    private func inboxRow(_ icon: String, _ title: String, _ detail: String, _ time: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color.opacity(0.18)).frame(width: 44, height: 44).overlay(Image(systemName: icon).foregroundStyle(color))
            VStack(alignment: .leading, spacing: 4) { Text(title).fontWeight(.bold); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Text(time).font(.caption2).foregroundStyle(.secondary)
        }.padding(.vertical, 5)
    }
}

struct SavedVideosSheet: View {
    @State private var videos: [FeedClip] = []
    @State private var errorMessage = ""
    var body: some View {
        NavigationStack {
            Group {
                if videos.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bookmark").font(.system(size: 34)).foregroundStyle(.secondary)
                        Text(errorMessage.isEmpty ? "No saved videos" : errorMessage).font(.headline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(videos) { video in
                                HStack(spacing: 12) {
                                    Image(systemName: "play.rectangle.fill").font(.system(size: 28)).foregroundStyle(.cyan)
                                    VStack(alignment: .leading) { Text(video.caption.isEmpty ? "Video" : video.caption).lineLimit(2); Text(video.handle).font(.caption).foregroundStyle(.secondary) }
                                }.padding(.horizontal)
                            }
                        }.padding(.vertical)
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Saved videos")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                do {
                    let (data, _) = try await LerizAPI.request("api/saved")
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                    let rows = json["videos"] as? [[String: Any]] ?? []
                    videos = rows.compactMap { row in
                        guard let id = row["id"] as? String else { return nil }
                        let user = row["user"] as? [String: Any] ?? [:]
                        let username = user["username"] as? String ?? "user"
                        return FeedClip(id: abs(id.hashValue % 2_000_000_000), creator: user["displayName"] as? String ?? username, handle: "@\(username)", caption: row["caption"] as? String ?? "", tags: "", song: "", likes: String(row["likes"] as? Int ?? 0), comments: String(row["comments"] as? Int ?? 0), views: row["views"] as? Int ?? 0, accent: .purple, videoURL: row["videoURL"] as? String ?? "\(LerizAPI.baseURL)/api/videos/\(id)/file", symbol: "person")
                    }
                } catch { errorMessage = "Could not load saved videos." }
            }
        }.preferredColorScheme(.dark)
    }
}

struct ShareSheet: View {
    let clip: FeedClip
    @State private var copied = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "paperplane").font(.system(size: 38)).foregroundStyle(.cyan).padding(.top, 30)
                Text("Share this Leriz video").font(.title2.bold())
                Text(clip.caption).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
                HStack(spacing: 24) {
                    shareTarget("message", "Messages", .green)
                    shareTarget("link", "Copy link", .cyan)
                    shareTarget("square.and.arrow.up", "More", .purple)
                }
                Button { UIPasteboard.general.string = "https://leriz.demo/video/\(clip.id)"; copied = true } label: {
                    Label(copied ? "Link copied" : "Copy demo link", systemImage: copied ? "checkmark.circle" : "doc.on.doc")
                        .fontWeight(.bold).frame(maxWidth: .infinity).padding(15).background(Color.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                }.padding(.horizontal)
                Spacer()
            }.navigationTitle("Share").navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.dark)
    }
    private func shareTarget(_ icon: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color).frame(width: 58, height: 58).background(color.opacity(0.14), in: Circle()); Text(title).font(.caption) }
    }
}

struct CreateVideoPage: View {
    let onPost: (String, URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var isRecording = false
    @State private var recordedURL: URL?
    @State private var showEditor = false
    @State private var permissionMessage: String?
    @State private var permissionsGranted = false
    @State private var isBackCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var recentThumbnail: UIImage?
    @StateObject private var recorder = LoopCameraRecorder()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { recorder.stopIfNeeded(); dismiss() }
                    Spacer()
                    Text("Create").font(.headline.bold())
                    Spacer()
                    Button("Next") { showEditor = true }.fontWeight(.bold).disabled(recordedURL == nil)
                }.padding(.horizontal, 18).padding(.vertical, 12)

                ZStack(alignment: .bottom) {
                    CameraCapturePreview(session: recorder.session)
                        .clipShape(Rectangle())
                        .padding(.horizontal, 10)
                    LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                        .frame(height: 130).clipShape(Rectangle())
                        .padding(.horizontal, 10).allowsHitTesting(false)
                    VStack(spacing: 8) {
                        if let permissionMessage {
                            Text(permissionMessage).font(.caption).multilineTextAlignment(.center)
                                .padding(10).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10))
                        }
                        if let recordedURL {
                            Label("Recording ready · tap Next to edit", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold()).foregroundStyle(.green)
                        } else {
                            Text("Record directly from the selected camera")
                                .font(.caption2).foregroundStyle(.white.opacity(0.8))
                        }
                    }.padding(.bottom, 16)
                }.frame(maxHeight: .infinity)

                HStack {
                    PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.videos, .images]), photoLibrary: .shared()) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let recentThumbnail {
                                    Image(uiImage: recentThumbnail).resizable().scaledToFill().frame(width: 54, height: 58).clipped()
                                } else {
                                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.12)).frame(width: 54, height: 58)
                                        .overlay(Image(systemName: "photo.on.rectangle").font(.system(size: 23)).foregroundStyle(.white))
                                }
                            }.frame(width: 54, height: 58).clipShape(RoundedRectangle(cornerRadius: 12))
                            Image(systemName: "plus.circle.fill").font(.system(size: 17)).symbolRenderingMode(.palette).foregroundStyle(.white, .cyan).offset(x: 4, y: 4)
                            if isImporting { ProgressView().tint(.white).scaleEffect(0.7) }
                        }
                    }
                    .disabled(isImporting || isRecording)
                    Spacer()
                    Button {
                        if isRecording {
                            recorder.stop()
                        } else {
                            recordedURL = nil
                            permissionMessage = nil
                            isRecording = true
                            recorder.start { error in
                                if let error { permissionMessage = error; isRecording = false }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle().stroke(.white.opacity(0.9), lineWidth: 4).frame(width: 78, height: 78)
                            RoundedRectangle(cornerRadius: isRecording ? 7 : 30)
                                .fill(Color(red: 0.98, green: 0.16, blue: 0.37))
                                .frame(width: isRecording ? 28 : 60, height: isRecording ? 28 : 60)
                                .animation(.spring(response: 0.28, dampingFraction: 0.68), value: isRecording)
                        }.frame(width: 88, height: 88)
                    }.buttonStyle(.plain).disabled(!permissionsGranted)
                    Spacer()
                    Button {
                        if let url = recordedURL {
                            UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                            permissionMessage = "Saved recording to Photos."
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 23))
                            .foregroundStyle(recordedURL == nil ? .white.opacity(0.35) : .white).frame(width: 54, height: 58)
                    }.disabled(recordedURL == nil)
                }.padding(.horizontal, 35).padding(.top, 12).padding(.bottom, 18)
                Text(isRecording ? "RECORDING · tap the red button to stop" : "Record a video with your camera")
                    .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .task { await requestPermissions(); loadRecentThumbnail() }
        .onDisappear { recorder.stopIfNeeded() }
        .onChange(of: recorder.outputURL) { value in
            if let value { recordedURL = value; isRecording = false; showEditor = true }
        }
        .onChange(of: recorder.failureMessage) { value in
            if let value { permissionMessage = value; isRecording = false }
        }
        .onChange(of: selectedPhoto) { item in
            guard let item else { return }
            Task { await importSelectedMedia(item) }
        }
        .fullScreenCover(isPresented: $showEditor) {
            if let url = recordedURL {
                VideoEditorView(url: url) { text, editedURL in
                    onPost(text, editedURL)
                }
            }
        }
    }

    private func loadRecentThumbnail() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 1
            options.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.video.rawValue, PHAssetMediaType.image.rawValue)
            guard let asset = PHAsset.fetchAssets(with: options).firstObject else { return }
            let requestOptions = PHImageRequestOptions()
            requestOptions.deliveryMode = .fastFormat
            requestOptions.resizeMode = .fast
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 180, height: 220), contentMode: .aspectFill, options: requestOptions) { image, _ in
                if let image { DispatchQueue.main.async { recentThumbnail = image } }
            }
        }
    }

    @MainActor
    private func importSelectedMedia(_ item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false; selectedPhoto = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                permissionMessage = "Could not read that media item. Try another one."
                return
            }
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                let ext = item.supportedContentTypes.first(where: { $0.conforms(to: .movie) })?.preferredFilenameExtension ?? "mp4"
                let target = FileManager.default.temporaryDirectory.appendingPathComponent("Leriz-import-\(UUID().uuidString).\(ext)")
                try data.write(to: target, options: .atomic)
                recordedURL = target
                showEditor = true
                loadRecentThumbnail()
                permissionMessage = nil
            } else if let image = UIImage(data: data), let stillVideo = await StillImageVideoExporter.export(image: image) {
                recordedURL = stillVideo
                showEditor = true
                loadRecentThumbnail()
                permissionMessage = nil
            } else {
                permissionMessage = "This image could not be prepared for upload."
            }
        } catch {
            permissionMessage = "Could not import media: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func requestPermissions() async {
        let cameraOK = await AVCaptureDevice.requestAccess(for: .video)
        guard cameraOK else { permissionMessage = "Camera permission is required."; return }
        let micOK = await AVCaptureDevice.requestAccess(for: .audio)
        guard micOK else { permissionMessage = "Microphone permission is required to record sound."; return }
        recorder.configure(position: .front) { error in
            if let error { permissionMessage = error } else { permissionsGranted = true }
        }
    }
}

final class StillImageVideoExporter {
    static func export(image: UIImage) async -> URL? {
        let size = CGSize(width: 720, height: 1280)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("Leriz-photo-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: output)
        guard let writer = try? AVAssetWriter(outputURL: output, fileType: .mp4) else { return nil }
        let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height)]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height), kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)
        guard let cgImage = image.cgImage else { writer.cancelWriting(); return nil }
        let queue = DispatchQueue(label: "leriz.photo-to-video")
        return await withCheckedContinuation { continuation in
            var frame = 0
            var didFinish = false
            input.requestMediaDataWhenReady(on: queue) {
                guard !didFinish else { return }
                while frame < 150 && input.isReadyForMoreMediaData {
                    var buffer: CVPixelBuffer?
                    guard let pool = adaptor.pixelBufferPool,
                          CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
                          let pixelBuffer = buffer else { writer.cancelWriting(); continuation.resume(returning: nil); return }
                    CVPixelBufferLockBaseAddress(pixelBuffer, [])
                    if let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
                        context.setFillColor(UIColor.black.cgColor)
                        context.fill(CGRect(origin: .zero, size: size))
                        let source = CGSize(width: cgImage.width, height: cgImage.height)
                        let scale = max(size.width / source.width, size.height / source.height)
                        let drawSize = CGSize(width: source.width * scale, height: source.height * scale)
                        context.draw(cgImage, in: CGRect(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2, width: drawSize.width, height: drawSize.height))
                    }
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                    if !adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) {
                        didFinish = true
                        writer.cancelWriting()
                        continuation.resume(returning: nil)
                        return
                    }
                    frame += 1
                }
                if frame >= 150 {
                    didFinish = true
                    input.markAsFinished()
                    writer.finishWriting { continuation.resume(returning: writer.status == .completed ? output : nil) }
                }
            }
        }
    }
}

struct VideoEditorView: View {
    let url: URL
    let onPost: (String, URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var textColor = Color.white
    @State private var opacity = 1.0
    @State private var useGradient = false
    @State private var useBorder = false
    @State private var showTextTools = false
    @State private var textOffset = CGSize.zero

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {
                    VideoPlayer(player: AVPlayer(url: url))
                    if !text.isEmpty {
                        Text(text)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(useGradient ? AnyShapeStyle(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(textColor))
                            .padding(5)
                            .background(useBorder ? Color.black.opacity(0.48) : .clear, in: RoundedRectangle(cornerRadius: 5))
                            .overlay { if useBorder { RoundedRectangle(cornerRadius: 5).stroke(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .leading, endPoint: .trailing), lineWidth: 2) } }
                            .opacity(opacity)
                            .offset(textOffset)
                            .gesture(DragGesture().onChanged { textOffset = $0.translation })
                    }
                }
                .clipShape(Rectangle())
                .padding(.horizontal, 12)
                TextField("Write a caption…", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 14)
                Text("Drag text on the video to position it").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .background(Color.black)
            .navigationTitle("Edit video").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Back") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showTextTools = true } label: { Image(systemName: "textformat") }
                        .accessibilityLabel("Edit text style")
                    Button("Post") {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onPost("", url)
                        } else {
                            Task {
                                if let rendered = await renderTextIntoVideo(text: text, sourceURL: url, color: UIColor(textColor), opacity: opacity, border: useBorder, gradient: useGradient) {
                                    await MainActor.run { onPost(text, rendered) }
                                } else {
                                    await MainActor.run { onPost(text, url) }
                                }
                            }
                        }
                    }.fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showTextTools) {
                NavigationStack {
                    Form {
                        Section("Text") {
                            TextField("Your text", text: $text, axis: .vertical)
                            Button(role: .destructive) { text = "" } label: { Label("Delete text", systemImage: "trash") }
                        }
                        Section("Color") {
                            HStack(spacing: 18) {
                                colorButton(.white); colorButton(.yellow); colorButton(.cyan); colorButton(.pink); colorButton(.green)
                            }
                            Toggle("Gradient text", isOn: $useGradient)
                            Toggle("Border", isOn: $useBorder)
                            VStack(alignment: .leading) {
                                Text("Transparency · \(Int(opacity * 100))%")
                                Slider(value: $opacity, in: 0...1)
                            }
                        }
                    }
                    .navigationTitle("Text style").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showTextTools = false } } }
                }.presentationDetents([.medium, .large]).preferredColorScheme(.dark)
            }
        }.preferredColorScheme(.dark)
    }

    private func renderTextIntoVideo(text: String, sourceURL: URL, color: UIColor, opacity: Double, border: Bool, gradient: Bool) async -> URL? {
        let asset = AVURLAsset(url: sourceURL)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let naturalSize = try? await track.load(.naturalSize),
              let duration = try? await asset.load(.duration) else { return nil }
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let range = try? await track.load(.timeRange) else { return nil }
        do { try videoTrack.insertTimeRange(range, of: track, at: .zero) } catch { return nil }
        if let audio = try? await asset.loadTracks(withMediaType: .audio).first,
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try? audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audio, at: .zero)
        }
        let videoSize = naturalSize.applying((try? await track.load(.preferredTransform)) ?? .identity)
        let width = abs(videoSize.width), height = abs(videoSize.height)
        let parent = CALayer()
        let videoLayer = CALayer()
        parent.frame = CGRect(x: 0, y: 0, width: width, height: height)
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.alignmentMode = .center
        textLayer.isWrapped = true
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.font = UIFont.systemFont(ofSize: max(26, width * 0.055), weight: .black)
        textLayer.fontSize = max(26, width * 0.055)
        textLayer.foregroundColor = (gradient ? UIColor.white : color).withAlphaComponent(opacity).cgColor
        textLayer.backgroundColor = border ? UIColor.black.withAlphaComponent(0.55).cgColor : UIColor.clear.cgColor
        textLayer.cornerRadius = 8
        textLayer.frame = CGRect(x: width * 0.06, y: height * 0.42 + textOffset.height, width: width * 0.88, height: min(height * 0.24, max(80, CGFloat(text.count / 24 + 1) * 52)))
        parent.addSublayer(textLayer)
        let instruction = AVMutableVideoComposition()
        instruction.renderSize = CGSize(width: width, height: height)
        instruction.frameDuration = CMTime(value: 1, timescale: 30)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform((try? await track.load(.preferredTransform)) ?? .identity, at: .zero)
        let videoInstruction = AVMutableVideoCompositionInstruction()
        videoInstruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        videoInstruction.layerInstructions = [layerInstruction]
        instruction.instructions = [videoInstruction]
        instruction.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("Leriz-edited-\(UUID().uuidString).mp4")
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return nil }
        exporter.outputURL = output
        exporter.outputFileType = .mp4
        exporter.videoComposition = instruction
        return await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume(returning: exporter.status == .completed ? output : nil)
            }
        }
    }

    private func colorButton(_ color: Color) -> some View {
        Button { textColor = color; useGradient = false } label: {
            Circle().fill(color).frame(width: 30, height: 30)
                .overlay(Circle().stroke(.white.opacity(textColor == color ? 1 : 0.2), lineWidth: 2))
        }.buttonStyle(.plain)
    }
}

struct SongDetailSheet: View {
    let clip: FeedClip
    let clips: [FeedClip]
    let onSelectClip: (FeedClip) -> Void
    @Environment(\.dismiss) private var dismiss

    private var songClips: [FeedClip] {
        clips.filter { $0.song.localizedCaseInsensitiveCompare(clip.song) == .orderedSame }
            .sorted { $0.views > $1.views }
    }
    private var gridClips: [FeedClip] {
        let sorted = songClips
        return stride(from: 0, to: sorted.count, by: 3).flatMap { start in
            Array(sorted[start..<min(start + 3, sorted.count)].reversed())
        }
    }
    private let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Rectangle().fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Image(systemName: "opticaldisc").font(.system(size: 32, weight: .regular)).foregroundStyle(.white)
                        }
                        .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(clip.song).font(.system(size: 17, weight: .bold)).lineLimit(2)
                            Text("Videos using this sound").font(.caption).foregroundStyle(.secondary)
                            Text("\(songClips.count) videos · sorted by views").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(10)
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(gridClips) { item in
                        Button {
                            onSelectClip(item)
                            dismiss()
                        } label: {
                            SongGridVideoTile(clip: item)
                                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                downloadVideo(item.videoURL)
                            } label: { Label("Download / Save video", systemImage: "arrow.down.to.line") }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
            .background(Color.black)
            .navigationTitle(clip.song)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").fontWeight(.semibold) }
                }
            }
        }.preferredColorScheme(.dark)
    }

    private func downloadVideo(_ rawURL: String) {
        guard let remoteURL = URL(string: rawURL) else { return }
        URLSession.shared.downloadTask(with: remoteURL) { temporaryURL, _, error in
            guard let temporaryURL, error == nil else { return }
            let localURL = FileManager.default.temporaryDirectory.appendingPathComponent("Leriz-download-\(UUID().uuidString).mp4")
            do {
                try FileManager.default.copyItem(at: temporaryURL, to: localURL)
                DispatchQueue.main.async {
                    UISaveVideoAtPathToSavedPhotosAlbum(localURL.path, nil, nil, nil)
                }
            } catch { }
        }.resume()
    }
}

struct SongGridVideoTile: View {
    let clip: FeedClip
    @State private var player = AVPlayer()
    @State private var frameIndex = 0
    private let frameCount = 6

    var body: some View {
        PlayerSurface(player: player)
            .frame(maxWidth: .infinity)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .background(clip.accent.gradient)
            .clipped()
            .onAppear {
                guard let url = URL(string: clip.videoURL) else { return }
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
                player.isMuted = true
                player.pause()
                seekPreview()
            }
            .onReceive(Timer.publish(every: 1.0 / 3.0, on: .main, in: .common).autoconnect()) { _ in
                guard player.currentItem != nil else { return }
                frameIndex = (frameIndex + 1) % frameCount
                seekPreview()
            }
            .onDisappear { player.pause() }
    }

    private func seekPreview() {
        player.seek(to: CMTime(seconds: Double(frameIndex) / 3.0, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

struct CameraCapturePreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {
        if view.videoPreviewLayer.session !== session { view.videoPreviewLayer.session = session }
    }
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

final class LoopCameraRecorder: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "leriz.camera-capture")
    private var currentPosition: AVCaptureDevice.Position = .front
    @Published private(set) var outputURL: URL?
    @Published private(set) var failureMessage: String?

    func configure(position: AVCaptureDevice.Position, completion: @escaping (String?) -> Void) {
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
    }

    private func installVideoInput(position: AVCaptureDevice.Position) throws {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInTripleCamera],
            mediaType: .video, position: position)
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw NSError(domain: "LerizCamera", code: 1, userInfo: [NSLocalizedDescriptionKey: position == .back ? "No back camera was found." : "No front camera was found."])
        }
        let newInput = try AVCaptureDeviceInput(device: device)
        let previousInputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.filter { $0.device.hasMediaType(.video) }
        previousInputs.forEach { session.removeInput($0) }
        guard session.canAddInput(newInput) else {
            previousInputs.forEach { if session.canAddInput($0) { session.addInput($0) } }
            throw NSError(domain: "LerizCamera", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not connect the selected camera. The previous camera has been restored."])
        }
        session.addInput(newInput)
        currentPosition = position
    }

    func switchCamera(to position: AVCaptureDevice.Position, completion: @escaping (String?) -> Void) {
        guard !movieOutput.isRecording else {
            DispatchQueue.main.async { completion("Stop recording before switching cameras.") }
            return
        }
        sessionQueue.async {
            do {
                let wasRunning = self.session.isRunning
                if wasRunning { self.session.stopRunning() }
                self.session.beginConfiguration()
                try self.installVideoInput(position: position)
                self.session.commitConfiguration()
                if wasRunning { self.session.startRunning() }
                self.currentPosition = position
                DispatchQueue.main.async { completion(nil) }
            } catch {
                self.session.commitConfiguration()
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { completion(error.localizedDescription) }
            }
        }
    }

    func start(completion: @escaping (String?) -> Void) {
        sessionQueue.async {
            guard self.session.isRunning else {
                DispatchQueue.main.async { completion("Camera is not ready yet. Try again.") }
                return
            }
            guard !self.movieOutput.isRecording else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Leriz-camera-\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: url)
            self.outputURL = nil
            self.failureMessage = nil
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async { completion(nil) }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
        }
    }

    func stopIfNeeded() {
        sessionQueue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.failureMessage = "Could not finish recording: \(error.localizedDescription)"
            } else {
                self.outputURL = outputFileURL
            }
        }
    }
}
