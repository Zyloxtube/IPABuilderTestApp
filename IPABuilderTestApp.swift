import SwiftUI
import AVKit
import UIKit
import ARKit
import SceneKit
import ReplayKit
import AVFoundation
import CoreMedia

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
        .init(id: 3, creator: "Weekend Frames", handle: "@weekendframes", caption: "A tiny reminder to go outside today ☀️", tags: "#weekend #travel #vibes", song: "soft focus · weekendframes", likes: "512K", comments: "8,091", accent: Color(red: 1.0, green: 0.42, blue: 0.29), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4", symbol: "sun.max"),
        .init(id: 4, creator: "The Daily Loop", handle: "@thedailyloop", caption: "This is your sign to try something new.", tags: "#motivation #tryit #fyp", song: "little by little · thedailyloop", likes: "76.4K", comments: "976", accent: Color(red: 0.20, green: 0.79, blue: 0.53), videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4", symbol: "bolt")
    ]
}

struct LoopFeedView: View {
    @State private var clips = FeedClip.samples
    @State private var selectedClip = 0
    @State private var showCreate = false
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
                            onProfile: { showProfile = true }
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
        .sheet(isPresented: $showSearch) { SearchSheet() }
        .fullScreenCover(isPresented: $showProfile) { ProfileSheet() }
        .fullScreenCover(isPresented: $showCreate) { CreateVideoPage { caption, recordedURL in
            let clip = FeedClip(id: (clips.map(\.id).max() ?? 0) + 1, creator: "Your Loop", handle: "@yourloop", caption: caption.isEmpty ? "My new Loop ✨" : caption, tags: "#loop #newpost", song: "original audio · yourloop", likes: "0", comments: "0", accent: .purple, videoURL: recordedURL.absoluteString, symbol: "person")
            clips.insert(clip, at: 0)
            selectedClip = 0
            showCreate = false
        } }
        .sheet(isPresented: $showInbox) { InboxSheet() }
        .sheet(isPresented: $showShare) { ShareSheet(clip: clips[selectedClip]) }
    }

    private var topBar: some View {
        HStack(spacing: 17) {
            HStack(spacing: 5) {
                Image(systemName: "infinity")
                    .font(.system(size: 25, weight: .regular))
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
                Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .regular)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .padding(.bottom, 15)
        .background(LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .top, endPoint: .bottom))
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
                            Button(isFollowing ? "Following" : "Follow") { isFollowing.toggle() }.font(.system(size: 13, weight: .bold)).foregroundStyle(isFollowing ? .white.opacity(0.8) : .cyan)
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
                                Image(systemName: "plus.circle").font(.system(size: 19)).foregroundStyle(.pink).offset(y: 8)
                            }
                        }
                        actionButton(isLiked ? "heart.fill" : "heart", value: isLiked ? "248.7K" : clip.likes, color: .white, gradient: isLiked, action: onLike)
                        actionButton("text.bubble", value: clip.comments, color: .white, action: onComments)
                        actionButton(isSaved ? "bookmark.fill" : "bookmark", value: isSaved ? "Saved" : "Save", color: isSaved ? Color(red: 1, green: 0.78, blue: 0.16) : .white, action: onSave)
                        actionButton("arrowshape.turn.up.right", value: "Share", color: .white, action: onShare)
                        Button { isMuted.toggle(); player.isMuted = isMuted } label: {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.16)).frame(width: 40, height: 40)
                                Image(systemName: "opticaldisc").font(.system(size: 27, weight: .regular)).foregroundStyle(.white)
                                if isMuted { Image(systemName: "speaker.slash").font(.system(size: 12, weight: .bold)).foregroundStyle(.yellow).offset(x: 13, y: 13) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 54)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 112)
            }

            if !isPlaying {
                Image(systemName: "play")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(24)
                    .background(.black.opacity(0.38), in: Circle())
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
    @Environment(\.dismiss) private var dismiss
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
                            Text("Your Loop").font(.title3.bold())
                            Text("@yourloop").font(.subheadline).foregroundStyle(.secondary)
                            Text("Creator on Loop").font(.caption).foregroundStyle(.secondary)
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
                    Text("Making little moments loop forever.").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18)
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
    @State private var name = "Your Loop"
    @State private var username = "yourloop"
    @State private var bio = "Making little moments loop forever."
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
                inboxRow("sparkles", "Welcome to loop", "Your new scroll starts here.", "Now", .cyan)
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
                Text("Share this loop").font(.title2.bold())
                Text(clip.caption).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
                HStack(spacing: 24) {
                    shareTarget("message", "Messages", .green)
                    shareTarget("link", "Copy link", .cyan)
                    shareTarget("square.and.arrow.up", "More", .purple)
                }
                Button { UIPasteboard.general.string = "https://loop.demo/video/\(clip.id)"; copied = true } label: {
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
    @State private var selectedFilter = 1
    @State private var isRecording = false
    @State private var recordedURL: URL?
    @State private var showPost = false
    @State private var permissionMessage: String?
    @State private var busy = false
    @StateObject private var recorder = LoopScreenRecorder()

    private let filters: [(String, FaceEffect)] = [
        ("None", .none), ("Dog", .dog), ("Cat", .cat), ("Robot", .robot), ("Glasses", .glasses)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { recorder.stopIfNeeded(); dismiss() }
                    Spacer()
                    Text("Create").font(.headline.bold())
                    Spacer()
                    Button("Next") { showPost = true }.fontWeight(.bold).disabled(recordedURL == nil)
                }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 12)

                ZStack(alignment: .bottom) {
                    FaceCameraView(effect: filters[selectedFilter].1)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 10)
                    LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
                        .frame(height: 145)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .padding(.horizontal, 10)
                        .allowsHitTesting(false)
                    VStack(spacing: 8) {
                        if let permissionMessage {
                            Text(permissionMessage).font(.caption).multilineTextAlignment(.center)
                                .padding(10).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                        }
                        if let recordedURL {
                            Label("Recording ready", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold()).foregroundStyle(.green)
                        } else {
                            Text("Face effects need a TrueDepth front camera")
                                .font(.caption2).foregroundStyle(.white.opacity(0.8))
                        }
                    }.padding(.bottom, 16)
                }
                .frame(maxHeight: .infinity)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(filters.indices, id: \.self) { index in
                            Button { selectedFilter = index } label: {
                                VStack(spacing: 7) {
                                    ZStack {
                                        Circle().fill(LinearGradient(colors: index == selectedFilter ? [.cyan, .purple] : [.white.opacity(0.16), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 58, height: 58)
                                        Image(systemName: filterSymbol(index))
                                            .font(.system(size: 24, weight: .medium)).foregroundStyle(.white)
                                        if index == selectedFilter {
                                            Circle().stroke(.white, lineWidth: 2).frame(width: 64, height: 64)
                                        }
                                    }
                                    Text(filters[index].0).font(.caption2.weight(index == selectedFilter ? .bold : .medium))
                                        .foregroundStyle(index == selectedFilter ? .white : .white.opacity(0.7))
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 22).padding(.vertical, 12)
                }

                HStack {
                    Button {
                        permissionMessage = "Use the front camera to record a Loop."
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera").font(.system(size: 23))
                            .foregroundStyle(.white).frame(width: 54, height: 58)
                    }
                    Spacer()
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle().fill(.white).frame(width: 82, height: 82)
                            Circle().stroke(.white.opacity(0.75), lineWidth: 3).frame(width: 72, height: 72)
                            RoundedRectangle(cornerRadius: isRecording ? 8 : 26)
                                .fill(isRecording ? .red : Color(red: 0.98, green: 0.16, blue: 0.37))
                                .frame(width: isRecording ? 28 : 60, height: isRecording ? 28 : 60)
                                .animation(.spring(response: 0.25), value: isRecording)
                        }
                    }.disabled(busy)
                    Spacer()
                    Button {
                        if let url = recordedURL { UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil); permissionMessage = "Saved recording to Photos." }
                    } label: {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 23))
                            .foregroundStyle(recordedURL == nil ? .white.opacity(0.35) : .white).frame(width: 54, height: 58)
                    }.disabled(recordedURL == nil)
                }.padding(.horizontal, 35).padding(.top, 4).padding(.bottom, 18)

                Text(isRecording ? "RECORDING · tap the red button to stop" : "Record a video with a live face effect")
                    .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .task { await requestPermissions() }
        .onChange(of: recorder.outputURL) { value in
            if let value { recordedURL = value; isRecording = false; busy = false }
        }
        .sheet(isPresented: $showPost) {
            NavigationStack {
                Form {
                    Section("Your video") {
                        TextField("Write a caption…", text: $caption, axis: .vertical)
                        LabeledContent("Face effect", value: filters[selectedFilter].0)
                        if let recordedURL {
                            VideoPlayer(player: AVPlayer(url: recordedURL)).frame(height: 240).listRowInsets(EdgeInsets())
                        }
                    }
                    Section {
                        Button("Post to Loop") {
                            guard let url = recordedURL else { return }
                            onPost(caption, url)
                        }.fontWeight(.bold).disabled(recordedURL == nil)
                    }
                }.navigationTitle("New post").navigationBarTitleDisplayMode(.inline)
            }.preferredColorScheme(.dark)
        }
    }

    private func filterSymbol(_ index: Int) -> String {
        ["face.smiling", "pawprint.fill", "cat.fill", "theatermasks.fill", "eyeglasses"][index]
    }

    @MainActor
    private func requestPermissions() async {
        guard ARFaceTrackingConfiguration.isSupported else {
            permissionMessage = "Face tracking is unavailable on this device. Try an iPhone with a TrueDepth front camera."
            return
        }
        let cameraOK = await AVCaptureDevice.requestAccess(for: .video)
        guard cameraOK else { permissionMessage = "Camera permission is required."; return }
        let micOK = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in continuation.resume(returning: granted) }
        }
        guard micOK else { permissionMessage = "Microphone permission is required to record sound."; return }
        permissionMessage = nil
    }

    private func toggleRecording() {
        if isRecording {
            busy = true
            recorder.stop()
        } else {
            recordedURL = nil
            permissionMessage = nil
            isRecording = true
            busy = true
            recorder.start { error in
                DispatchQueue.main.async {
                    if let error {
                        isRecording = false
                        busy = false
                        permissionMessage = error
                    }
                }
            }
        }
    }
}

enum FaceEffect: Int {
    case none, dog, cat, robot, glasses
}

struct FaceCameraView: UIViewRepresentable {
    let effect: FaceEffect

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.automaticallyUpdatesLighting = true
        view.delegate = context.coordinator
        context.coordinator.sceneView = view
        guard ARFaceTrackingConfiguration.isSupported else { return view }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.setEffect(effect)
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        context.coordinator.setEffect(effect)
    }

    static func dismantleUIView(_ view: ARSCNView, coordinator: Coordinator) {
        view.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        weak var sceneView: ARSCNView?
        var effect: FaceEffect = .dog

        func setEffect(_ newEffect: FaceEffect) {
            effect = newEffect
            guard let anchors = sceneView?.scene.rootNode.childNodes else { return }
            for node in anchors { removeEffectNodes(from: node) }
            for anchor in (sceneView?.session.currentFrame?.anchors ?? []) {
                if let face = anchor as? ARFaceAnchor, let node = sceneView?.node(for: face) {
                    addEffectNodes(to: node, effect: newEffect)
                }
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor else { return nil }
            let root = SCNNode()
            addEffectNodes(to: root, effect: effect)
            return root
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard anchor is ARFaceAnchor else { return }
            removeEffectNodes(from: node)
            addEffectNodes(to: node, effect: effect)
        }

        private func removeEffectNodes(from root: SCNNode) {
            root.childNodes.filter { $0.name == "loop-face-effect" }.forEach { $0.removeFromParentNode() }
        }

        private func addEffectNodes(to root: SCNNode, effect: FaceEffect) {
            guard effect != .none else { return }
            let group = SCNNode()
            group.name = "loop-face-effect"
            switch effect {
            case .none: break
            case .dog:
                let brown = UIColor(red: 0.56, green: 0.30, blue: 0.13, alpha: 1)
                group.addChildNode(ear(x: -0.073, tilt: -0.32, color: brown))
                group.addChildNode(ear(x: 0.073, tilt: 0.32, color: brown))
                group.addChildNode(sphere(position: SCNVector3(0, -0.035, 0.105), scale: SCNVector3(0.035, 0.027, 0.025), color: UIColor.black))
                group.addChildNode(sphere(position: SCNVector3(0, -0.075, 0.09), scale: SCNVector3(0.025, 0.012, 0.012), color: UIColor.systemPink))
            case .cat:
                group.addChildNode(catEar(x: -0.07))
                group.addChildNode(catEar(x: 0.07))
                group.addChildNode(sphere(position: SCNVector3(0, -0.035, 0.105), scale: SCNVector3(0.018, 0.014, 0.012), color: UIColor.systemPink))
                group.addChildNode(whisker(x: -0.045, y: -0.05, rotation: -0.12))
                group.addChildNode(whisker(x: 0.045, y: -0.05, rotation: 0.12))
            case .robot:
                let mask = SCNBox(width: 0.15, height: 0.07, length: 0.025, chamferRadius: 0.012)
                let node = SCNNode(geometry: mask)
                node.position = SCNVector3(0, -0.045, 0.09)
                node.geometry?.firstMaterial?.diffuse.contents = UIColor.systemTeal
                node.geometry?.firstMaterial?.metalness.contents = 0.7
                group.addChildNode(node)
                for x: Float in [-0.035, 0.035] {
                    group.addChildNode(sphere(position: SCNVector3(x, -0.015, 0.11), scale: SCNVector3(0.012, 0.012, 0.008), color: UIColor.cyan))
                }
            case .glasses:
                for x: Float in [-0.037, 0.037] {
                    let ring = SCNTorus(ringRadius: 0.025, pipeRadius: 0.004)
                    ring.firstMaterial?.diffuse.contents = UIColor.black
                    let node = SCNNode(geometry: ring)
                    node.position = SCNVector3(x, 0.025, 0.105)
                    group.addChildNode(node)
                }
                let bridge = SCNCylinder(radius: 0.003, height: 0.035)
                bridge.firstMaterial?.diffuse.contents = UIColor.black
                let node = SCNNode(geometry: bridge)
                node.eulerAngles.z = Float.pi / 2
                node.position = SCNVector3(0, 0.025, 0.105)
                group.addChildNode(node)
            }
            root.addChildNode(group)
        }

        private func sphere(position: SCNVector3, scale: SCNVector3, color: UIColor) -> SCNNode {
            let geometry = SCNSphere(radius: 1)
            geometry.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: geometry)
            node.position = position
            node.scale = scale
            return node
        }

        private func ear(x: Float, tilt: Float, color: UIColor) -> SCNNode {
            let geometry = SCNSphere(radius: 1)
            geometry.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(x, 0.09, 0.015)
            node.scale = SCNVector3(0.035, 0.065, 0.018)
            node.eulerAngles.z = tilt
            return node
        }

        private func catEar(x: Float) -> SCNNode {
            let geometry = SCNCone(topRadius: 0, bottomRadius: 0.035, height: 0.07)
            geometry.firstMaterial?.diffuse.contents = UIColor.systemPink
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(x, 0.09, 0.015)
            node.eulerAngles.z = x < 0 ? 0.28 : -0.28
            return node
        }

        private func whisker(x: Float, y: Float, rotation: Float) -> SCNNode {
            let geometry = SCNCylinder(radius: 0.0015, height: 0.07)
            geometry.firstMaterial?.diffuse.contents = UIColor.white
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(x, y, 0.095)
            node.eulerAngles.z = rotation
            return node
        }
    }
}

final class LoopScreenRecorder: ObservableObject {
    @Published private(set) var outputURL: URL?
    private let recorder = RPScreenRecorder.shared()
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var stopping = false
    private var startCompletion: ((String?) -> Void)?
    private let queue = DispatchQueue(label: "loop.screen-recorder")

    func start(completion: @escaping (String?) -> Void) {
        outputURL = nil
        sessionStarted = false
        stopping = false
        startCompletion = completion
        guard recorder.isAvailable else {
            completion("Screen recording is unavailable on this device.")
            return
        }
        recorder.isMicrophoneEnabled = true
        recorder.startCapture(handler: { [weak self] sample, type, error in
            guard let self, error == nil else { return }
            self.queue.async {
                if type == .video {
                    self.prepareWriterIfNeeded(sample)
                    guard let writer = self.writer, let input = self.videoInput else { return }
                    let time = CMSampleBufferGetPresentationTimeStamp(sample)
                    if writer.status == .unknown {
                        writer.startWriting()
                        writer.startSession(atSourceTime: time)
                        self.sessionStarted = true
                        DispatchQueue.main.async { self.startCompletion?(nil); self.startCompletion = nil }
                    }
                    if input.isReadyForMoreMediaData { input.append(sample) }
                } else if type == .audioMic, self.sessionStarted, let input = self.audioInput, input.isReadyForMoreMediaData {
                    input.append(sample)
                }
            }
        }, completionHandler: { [weak self] error in
            if let error { DispatchQueue.main.async { completion("Could not start recording: \(error.localizedDescription)") } }
        })
    }

    private func prepareWriterIfNeeded(_ sample: CMSampleBuffer) {
        guard writer == nil,
              let description = CMSampleBufferGetFormatDescription(sample) else { return }
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Loop-\(UUID().uuidString).mp4")
        do {
            let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(dimensions.width),
                AVVideoHeightKey: Int(dimensions.height)
            ])
            video.expectsMediaDataInRealTime = true
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 96000
            ])
            audio.expectsMediaDataInRealTime = true
            if assetWriter.canAdd(video) { assetWriter.add(video) }
            if assetWriter.canAdd(audio) { assetWriter.add(audio) }
            writer = assetWriter
            videoInput = video
            audioInput = audio
        } catch {
            DispatchQueue.main.async { self.startCompletion?(error.localizedDescription); self.startCompletion = nil }
        }
    }

    func stop() {
        guard !stopping else { return }
        stopping = true
        recorder.stopCapture { [weak self] error in
            guard let self else { return }
            self.queue.async {
                guard let writer = self.writer else {
                    DispatchQueue.main.async { self.startCompletion?("No video frames were recorded."); self.startCompletion = nil }
                    return
                }
                self.videoInput?.markAsFinished()
                self.audioInput?.markAsFinished()
                writer.finishWriting {
                    DispatchQueue.main.async {
                        if let error {
                            self.startCompletion?(error.localizedDescription)
                        } else if writer.status == .completed {
                            self.outputURL = writer.outputURL
                        } else {
                            self.startCompletion?(writer.error?.localizedDescription ?? "Could not finish the video.")
                        }
                        self.startCompletion = nil
                    }
                }
            }
        }
    }

    func stopIfNeeded() {
        if recorder.isRecording { stop() }
    }
}
