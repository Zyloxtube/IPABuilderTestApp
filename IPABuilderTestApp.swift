import SwiftUI
import AVKit

@main
struct IPABuilderTestApp: App {
    var body: some Scene {
        WindowGroup {
            LoopFeedView()
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
    let accent: Color
    let videoURL: String
    let symbol: String

    static let samples: [FeedClip] = [
        .init(id: 1, creator: "Milo Makes", handle: "@milomakes", caption: "POV: you found the quietest place on Earth 🌊", tags: "#ocean #escape #loop", song: "original audio · milomakes", likes: "248.6K", comments: "3,842", accent: Color(red: 0.08, green: 0.72, blue: 0.79), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", symbol: "water.waves"),
        .init(id: 2, creator: "Pixel Planet", handle: "@pixelplanet", caption: "The internet is a very strange place. Stay curious.", tags: "#weird #internet #facts", song: "NEON DREAMS · pixelplanet", likes: "91.2K", comments: "1,204", accent: Color(red: 0.57, green: 0.27, blue: 0.96), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", symbol: "sparkles"),
        .init(id: 3, creator: "Weekend Frames", handle: "@weekendframes", caption: "A tiny reminder to go outside today ☀️", tags: "#weekend #travel #vibes", song: "soft focus · weekendframes", likes: "512K", comments: "8,091", accent: Color(red: 1.0, green: 0.42, blue: 0.29), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4", symbol: "sun.max.fill"),
        .init(id: 4, creator: "The Daily Loop", handle: "@thedailyloop", caption: "This is your sign to try something new.", tags: "#motivation #tryit #fyp", song: "little by little · thedailyloop", likes: "76.4K", comments: "976", accent: Color(red: 0.20, green: 0.79, blue: 0.53), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4", symbol: "bolt.fill")
    ]
}

struct LoopFeedView: View {
    @State private var selectedClip = 0
    @State private var likedIDs: Set<Int> = []
    @State private var savedIDs: Set<Int> = []
    @State private var selectedTab = "For You"
    @State private var showComments = false
    @State private var showSearch = false
    @State private var showProfile = false
    @State private var showInbox = false
    @State private var showShare = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selectedClip) {
                ForEach(Array(FeedClip.samples.enumerated()), id: \.element.id) { index, clip in
                    ClipPage(
                        clip: clip,
                        isActive: selectedClip == index,
                        isLiked: likedIDs.contains(clip.id),
                        isSaved: savedIDs.contains(clip.id),
                        onLike: { toggle(clip.id, in: &likedIDs) },
                        onSave: { toggle(clip.id, in: &savedIDs) },
                        onComments: { showComments = true },
                        onShare: { showShare = true },
                        onProfile: { showProfile = true }
                    )
                    .tag(index)
                    .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showComments) { CommentsSheet(clip: FeedClip.samples[selectedClip]) }
        .sheet(isPresented: $showSearch) { SearchSheet() }
        .sheet(isPresented: $showProfile) { ProfileSheet() }
        .sheet(isPresented: $showInbox) { InboxSheet() }
        .sheet(isPresented: $showShare) { ShareSheet(clip: FeedClip.samples[selectedClip]) }
    }

    private var topBar: some View {
        HStack(spacing: 17) {
            HStack(spacing: 5) {
                Image(systemName: "infinity")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("loop")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .tracking(-1.2)
            }
            Spacer()
            Button { selectedTab = "Following" } label: {
                Text("Following")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedTab == "Following" ? .white : .white.opacity(0.62))
            }
            Button { selectedTab = "For You" } label: {
                VStack(spacing: 5) {
                    Text("For You")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Capsule().fill(Color.cyan).frame(width: 28, height: 3).opacity(selectedTab == "For You" ? 1 : 0)
                }
            }
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 21, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .padding(.bottom, 15)
        .background(LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .top, endPoint: .bottom))
    }

    private var bottomBar: some View {
        HStack {
            navButton("house.fill", title: "Home", selected: true) {}
            Spacer()
            navButton("safari", title: "Discover", selected: false) { showSearch = true }
            Spacer()
            Button { showShare = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(LinearGradient(colors: [.cyan, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 43, height: 31)
                    Image(systemName: "plus").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                }
            }
            Spacer()
            navButton("bubble.left.and.bubble.right.fill", title: "Inbox", selected: false) { showInbox = true }
            Spacer()
            navButton("person.crop.circle", title: "Profile", selected: false) { showProfile = true }
        }
        .padding(.horizontal, 24)
        .padding(.top, 13)
        .padding(.bottom, 30)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.88), .black], startPoint: .top, endPoint: .bottom))
    }

    private func navButton(_ symbol: String, title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 21, weight: selected ? .bold : .regular))
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
    @State private var player = AVPlayer()
    @State private var isPlaying = true
    @State private var videoFailed = false

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
                    .onTapGesture {
                        if isPlaying { player.pause() } else { player.play() }
                        isPlaying.toggle()
                    }
            }
            LinearGradient(colors: [.black.opacity(0.22), .clear, .clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle().fill(clip.accent).frame(width: 38, height: 38)
                                Image(systemName: clip.symbol).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            }
                            Text(clip.creator).font(.system(size: 15, weight: .bold))
                            Text("·").foregroundStyle(.white.opacity(0.6))
                            Text("Follow").font(.system(size: 13, weight: .bold)).foregroundStyle(.cyan)
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
                        Button(action: onProfile) {
                            ZStack(alignment: .bottom) {
                                Circle().fill(clip.accent).frame(width: 46, height: 46)
                                Image(systemName: clip.symbol).font(.system(size: 21, weight: .bold)).foregroundStyle(.white).frame(width: 46, height: 46)
                                Image(systemName: "plus.circle.fill").font(.system(size: 19)).foregroundStyle(.pink).offset(y: 8)
                            }
                        }
                        actionButton(isLiked ? "heart.fill" : "heart", value: isLiked ? "248.7K" : clip.likes, color: isLiked ? .pink : .white, action: onLike)
                        actionButton("bubble.right.fill", value: clip.comments, color: .white, action: onComments)
                        actionButton(isSaved ? "bookmark.fill" : "bookmark", value: isSaved ? "Saved" : "Save", color: isSaved ? .cyan : .white, action: onSave)
                        actionButton("arrowshape.turn.up.right.fill", value: "Share", color: .white, action: onShare)
                        ZStack {
                            Circle().fill(Color.white.opacity(0.16)).frame(width: 40, height: 40)
                            Image(systemName: "opticaldisc.fill").font(.system(size: 27)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 54)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 112)
            }

            if !isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(24)
                    .background(.black.opacity(0.38), in: Circle())
            }
        }
        .background(Color.black)
        .onAppear { if isActive { player.play() } }
    }

    private func actionButton(_ symbol: String, value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 27, weight: .semibold)).foregroundStyle(color).shadow(color: .black.opacity(0.25), radius: 4)
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
    @State private var comment = ""
    @State private var posted: [String] = ["This edit is everything 🔥", "needed this on my feed", "the vibes are immaculate"]
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(.cyan)
                    Text("\(clip.comments) comments").font(.headline)
                }.padding()
                ScrollView {
                    ForEach(Array(posted.enumerated()), id: \.offset) { _, text in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(Color.purple.gradient).frame(width: 34, height: 34).overlay(Image(systemName: "person.fill").foregroundStyle(.white))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(["loopfan_24", "noor.exe", "pixelkid"][posted.firstIndex(of: text).map { $0 % 3 } ?? 0]).font(.caption.bold()).foregroundStyle(.secondary)
                                Text(text)
                                HStack(spacing: 12) { Text("2h").font(.caption2).foregroundStyle(.secondary); Image(systemName: "heart").font(.caption).foregroundStyle(.secondary); Text("Reply").font(.caption2).foregroundStyle(.secondary) }
                            }
                            Spacer()
                        }.padding(.horizontal).padding(.vertical, 10)
                    }
                }
                HStack {
                    TextField("Add a comment…", text: $comment).textFieldStyle(.roundedBorder)
                    Button("Post") { if !comment.trimmingCharacters(in: .whitespaces).isEmpty { posted.insert(comment, at: 0); comment = "" } }.fontWeight(.bold).foregroundStyle(.cyan)
                }.padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") {}.foregroundStyle(.cyan) } }
        }
        .preferredColorScheme(.dark)
    }
}

struct SearchSheet: View {
    @State private var query = ""
    let trends = ["#loopchallenge", "#travelcore", "#oddlysatisfying", "#gaming", "#dailyvibes", "#foodtok"]
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search creators, sounds, tags", text: $query)
                }.padding(12).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                Text("TRENDING NOW").font(.caption.bold()).foregroundStyle(.secondary).tracking(1.5)
                ForEach(trends.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { tag in
                    HStack { Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.pink); Text(tag).fontWeight(.semibold); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(.secondary) }
                    Divider()
                }
                Spacer()
            }.padding()
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.dark)
    }
}

struct ProfileSheet: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                ZStack {
                    Circle().fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 104, height: 104)
                    Image(systemName: "person.fill").font(.system(size: 45)).foregroundStyle(.white)
                }
                Text("Your Loop").font(.title.bold())
                Text("@yourloop").foregroundStyle(.secondary)
                HStack(spacing: 36) {
                    stat("0", "Following")
                    stat("0", "Followers")
                    stat("0", "Likes")
                }.padding(.vertical, 12)
                Button {} label: {
                    Label("Edit profile", systemImage: "pencil").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(13).background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }.padding(.horizontal, 32)
                Text("Your videos will live here.").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.dark)
    }
    private func stat(_ number: String, _ label: String) -> some View {
        VStack(spacing: 4) { Text(number).font(.title3.bold()); Text(label).font(.caption).foregroundStyle(.secondary) }
    }
}

struct InboxSheet: View {
    var body: some View {
        NavigationStack {
            List {
                inboxRow("sparkles", "Welcome to loop", "Your new scroll starts here.", "Now", .cyan)
                inboxRow("heart.fill", "Activity", "When people like your videos, you'll see it here.", "Today", .pink)
                inboxRow("person.2.fill", "New creators", "Find your next favorite creator.", "Today", .purple)
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
                Image(systemName: "paperplane.fill").font(.system(size: 38)).foregroundStyle(.cyan).padding(.top, 30)
                Text("Share this loop").font(.title2.bold())
                Text(clip.caption).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
                HStack(spacing: 24) {
                    shareTarget("message.fill", "Messages", .green)
                    shareTarget("link", "Copy link", .cyan)
                    shareTarget("square.and.arrow.up", "More", .purple)
                }
                Button { UIPasteboard.general.string = "https://loop.demo/video/\(clip.id)"; copied = true } label: {
                    Label(copied ? "Link copied" : "Copy demo link", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
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
