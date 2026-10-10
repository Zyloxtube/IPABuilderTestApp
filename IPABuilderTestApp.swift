import SwiftUI
import Combine
import AVKit
import UIKit
import ARKit
import SceneKit
import ReplayKit
import AVFoundation
import CoreMedia

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

    static let samples: [FeedClip] = [
        .init(id: 1, creator: "Milo Makes", handle: "@milomakes", caption: "POV: you found the quietest place on Earth 🌊", tags: "#ocean #escape #leriz", song: "original audio · milomakes", likes: "248.6K", comments: "3,842", views: 2_400_000, accent: Color(red: 0.08, green: 0.72, blue: 0.79), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", symbol: "water.waves"),
        .init(id: 2, creator: "Pixel Planet", handle: "@pixelplanet", caption: "The internet is a very strange place. Stay curious.", tags: "#weird #internet #facts", song: "NEON DREAMS · pixelplanet", likes: "91.2K", comments: "1,204", views: 890_000, accent: Color(red: 0.57, green: 0.27, blue: 0.96), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", symbol: "sparkles"),
        .init(id: 3, creator: "Weekend Frames", handle: "@weekendframes", caption: "A tiny reminder to go outside today ☀️", tags: "#weekend #travel #vibes", song: "soft focus · weekendframes", likes: "512K", comments: "8,091", views: 4_700_000, accent: Color(red: 1.0, green: 0.42, blue: 0.29), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4", symbol: "sun.max"),
        .init(id: 4, creator: "The Daily Loop", handle: "@thedailyloop", caption: "This is your sign to try something new.", tags: "#motivation #tryit #fyp", song: "little by little · thedailyloop", likes: "76.4K", comments: "976", views: 630_000, accent: Color(red: 0.20, green: 0.79, blue: 0.53), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4", symbol: "bolt")
    ]
}


struct LerizLaunchView: View {
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var showWelcome = false
    @State private var enterApp = false

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
                    Text("DEMO MODE · No account is created and no data is sent.")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.42))
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 1)
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
        isLoading = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.65)) {
                isLoading = false
                showWelcome = true
            }
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeInOut(duration: 1.0)) {
                enterApp = true
            }
        }
    }
}

struct LoopFeedView: View {
    @State private var clips = FeedClip.samples
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
            GeometryReader { geometry in
                TabView(selection: $selectedClip) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        ClipPage(
                            clip: clip,
                            isActive: selectedClip == index,
                            isLiked: likedIDs.contains(clip.id),
                            isSaved: savedIDs.contains(clip.id),
                            onLike: { toggle(clip.id, in: &likedIDs) },
                            onSave: { toggle(clip.id, in: &savedIDs) },
                            onComments: { showComments = true },
                            onShare: { showShare = true },
                            onProfile: { selectedProfileClip = clip },
                            onSong: { selectedSongClip = clip }
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
        .sheet(isPresented: $showComments) { CommentsSheet(clip: clips[selectedClip]) }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
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
        .fullScreenCover(isPresented: $showCreate) { CreateVideoPage { caption, recordedURL in
            let clip = FeedClip(id: (clips.map(\.id).max() ?? 0) + 1, creator: "Your Leriz", handle: "@yourleriz", caption: caption.isEmpty ? "My new Leriz ✨" : caption, tags: "#leriz #newpost", song: "original audio · yourloop", likes: "0", comments: "0", views: 0, accent: .purple, videoURL: recordedURL.absoluteString, symbol: "person")
            clips.insert(clip, at: 0)
            selectedClip = 0
            showCreate = false
        } }
        .sheet(isPresented: $showInbox) { InboxSheet() }
        .sheet(isPresented: $showShare) { ShareSheet(clip: clips[selectedClip]) }
        .sheet(item: $selectedSongClip) { songClip in
            SongDetailSheet(clip: songClip, clips: clips) { chosenClip in
                if let index = clips.firstIndex(where: { $0.id == chosenClip.id }) { selectedClip = index }
            }
        }
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

    private func toggle(_ id: Int, in set: inout Set<Int>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
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
                        if active { player.play(); isPlaying = true } else { player.pause() }                    }
                    .onDisappear { player.pause() }
                    .onTapGesture {
                        if isPlaying { player.pause() } else { player.play() }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { isPlaying.toggle() }
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
                        actionButton(isLiked ? "heart.fill" : "heart", value: isLiked ? "248.7K" : clip.likes, color: .white, gradient: isLiked, action: onLike)
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
    @State private var posted: [String] = ["This edit is everything 🔥", "needed this on my feed", "the vibes are immaculate"]
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
                }
                .onDisappear { previewPlayer.pause() }

                Divider().overlay(Color.white.opacity(0.08))

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(posted.enumerated()), id: \.offset) { index, text in
                            HStack(alignment: .top, spacing: 11) {
                                Circle().fill(LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 38, height: 38)
                                    .overlay(Image(systemName: "person").font(.system(size: 15)).foregroundStyle(.white))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(["loopfan_24", "noor.exe", "pixelkid"][index % 3])
                                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                                    Text(text).font(.system(size: 14))
                                    HStack(spacing: 14) {
                                        Text("2h").font(.caption).foregroundStyle(.secondary)
                                        Button("Reply") { comment = "@\(["loopfan_24", "noor.exe", "pixelkid"][index % 3]) "; commentFieldFocused = true }
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
                    Button { commentFieldFocused = false } label: {
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

    private func postComment() {
        let clean = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        posted.insert(clean, at: 0)
        comment = ""
        commentFieldFocused = false
    }
}

struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var isTrendingSelected = false
    @State private var showTrendingPage = false
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
                                ForEach(matchingClips.sorted { $0.views > $1.views }) { clip in
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
                            Button { query = tag } label: {
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
                            ForEach(popularClips) { clip in
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
                TrendingVideosPage(clips: clips, onSelectClip: { chosen in
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

    private var rankedClips: [FeedClip] { clips.sorted { $0.views > $1.views } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                ForEach(Array(rankedClips.enumerated()), id: \.element.id) { index, clip in
                    Button {
                        onSelectClip(clip)
                        dismiss()
                    } label: {
                        HStack(spacing: 13) {
                            Text("#\(index + 1)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(index == 0 ? .yellow : .secondary)
                                .frame(width: 27)
                            VideoPreviewTile(clip: clip)
                                .frame(width: 108)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(clip.caption).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(3)
                                Text(clip.creator + " · " + clip.handle).font(.caption).foregroundStyle(.white.opacity(0.65))
                                Label("\(clip.views.formatted()) views", systemImage: "play.fill")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.cyan)
                                Text(clip.tags).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Trending now")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct VideoPreviewTile: View {
    let clip: FeedClip
    @State private var player = AVPlayer()
    @State private var frameIndex = 0
    private let frameCount = 6

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PlayerSurface(player: player)
                .frame(maxWidth: .infinity)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipped()
                .background(clip.accent.gradient)
            LinearGradient(colors: [.clear, .black.opacity(0.58)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(.black.opacity(0.48), in: Circle())
                Text(clip.views.formatted())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(7)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
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
        .allowsHitTesting(false)
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
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 16) {
                        Circle().fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 88, height: 88).overlay(Image(systemName: "person").font(.system(size: 40)))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(clip?.creator ?? "Your Leriz").font(.title3.bold())
                            Text(clip?.handle ?? "@yourleriz").font(.subheadline).foregroundStyle(.secondary)
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
                    Text("Capture your world, your way.").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18)
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
                ToolbarItem(placement: .topBarTrailing) { Button { showEdit = true } label: { Image(systemName: "line.3.horizontal") } }
            }
            .sheet(isPresented: $showEdit) { EditProfileDemo() }
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
    @State private var name = "Your Leriz"
    @State private var username = "yourleriz"
    @State private var bio = "Capture your world, your way."
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") { TextField("Name", text: $name); TextField("Username", text: $username); TextField("Bio", text: $bio, axis: .vertical) }
                Section { Text("Demo only — edits are not saved to a server.").font(.caption).foregroundStyle(.secondary) }
            }.navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

struct InboxSheet: View {
    var body: some View {
        NavigationStack {
            List {
                inboxRow("sparkles", "Welcome to Leriz", "Your new scroll starts here.", "Now", .cyan)
                inboxRow("heart", "Activity", "When people like your videos, you'll see it here.", "Today", .pink)
                inboxRow("person.2", "New creators", "Find your next favorite creator.", "Today", .purple)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
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
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 10)
                    LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                        .frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 22))
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
                    Button {
                        isBackCamera.toggle()
                        recorder.switchCamera(to: isBackCamera ? .back : .front) { error in
                            if let error { permissionMessage = error }
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera").font(.system(size: 23))
                            .foregroundStyle(.white).frame(width: 54, height: 58)
                    }
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
        .task { await requestPermissions() }
        .onDisappear { recorder.stopIfNeeded() }
        .onChange(of: recorder.outputURL) { value in
            if let value { recordedURL = value; isRecording = false; showEditor = true }
        }
        .onChange(of: recorder.failureMessage) { value in
            if let value { permissionMessage = value; isRecording = false }
        }
        .fullScreenCover(isPresented: $showEditor) {
            if let url = recordedURL {
                VideoEditorView(url: url) { text, editedURL in
                    onPost(text, editedURL)
                }
            }
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
                .clipShape(RoundedRectangle(cornerRadius: 18))
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
                    Button("Post") { onPost(text, url) }.fontWeight(.bold)
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
                LazyVGrid(columns: columns, spacing: 3) {
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
                .padding(.horizontal, 3)
                .padding(.top, 3)
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
        for input in session.inputs {
            if let videoInput = input as? AVCaptureDeviceInput, videoInput.device.hasMediaType(.video) {
                session.removeInput(videoInput)
            }
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInDualWideCamera],
            mediaType: .video, position: position)
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw NSError(domain: "LerizCamera", code: 1, userInfo: [NSLocalizedDescriptionKey: position == .back ? "No back camera was found." : "No front camera was found."])
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "LerizCamera", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not connect the selected camera."])
        }
        session.addInput(input)
        currentPosition = position
    }

    func switchCamera(to position: AVCaptureDevice.Position, completion: @escaping (String?) -> Void) {
        guard !movieOutput.isRecording else {
            DispatchQueue.main.async { completion("Stop recording before switching cameras.") }
            return
        }
        sessionQueue.async {
            do {
                self.session.beginConfiguration()
                try self.installVideoInput(position: position)
                self.session.commitConfiguration()
                self.currentPosition = position
                DispatchQueue.main.async { completion(nil) }
            } catch {
                self.session.commitConfiguration()
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
