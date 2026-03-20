import SwiftUI
import Photos
import AVKit

struct VideoAsset: Identifiable {
    let id = UUID()
    let phAsset: PHAsset
    let title: String
    let durationString: String
    let creationDateString: String
    let qualityString: String
}

class GalleryViewModel: ObservableObject {
    @Published var videos: [VideoAsset] = []
    @Published var permissionGranted = false
    @Published var searchText = ""
    @Published var selectedVideoURL: URL?
    @Published var isPlayingVideo = false
    
    var filteredVideos: [VideoAsset] {
        if searchText.isEmpty { return videos }
        return videos.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    func playVideo(_ asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                DispatchQueue.main.async {
                    self?.selectedVideoURL = urlAsset.url
                    self?.isPlayingVideo = true
                }
            }
        }
    }
    
    func requestPermissionAndLoad() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    self?.permissionGranted = true
                    self?.loadVideos()
                }
            }
        }
    }
    
    func loadVideos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let albumFetchOptions = PHFetchOptions()
        albumFetchOptions.predicate = NSPredicate(format: "title = %@", "GoPrompt")
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumFetchOptions)
        
        guard let album = collection.firstObject else {
            DispatchQueue.main.async { self.videos = [] }
            return
        }
        
        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        var loadedVideos: [VideoAsset] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy • HH:mm"
        
        fetchResult.enumerateObjects { (asset, count, stop) in
            guard asset.mediaType == .video else { return }
            if count >= 40 { stop.pointee = true; return }
            
            let durationString = self.formatDuration(asset.duration)
            let dateString = asset.creationDate.map { dateFormatter.string(from: $0) } ?? "Unknown Date"
            let quality = "\(asset.pixelHeight)P"
            
            // Retrieve custom title from UserDefaults linked to localIdentifier
            let customTitle = UserDefaults.standard.string(forKey: "video_title_\(asset.localIdentifier)") ?? "Recording"
            
            loadedVideos.append(VideoAsset(
                phAsset: asset,
                title: customTitle,
                durationString: durationString,
                creationDateString: dateString,
                qualityString: quality
            ))
        }
        
        DispatchQueue.main.async {
            self.videos = loadedVideos
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PHAssetThumbnailView: View {
    let asset: PHAsset
    let size: CGSize
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(DesignSystem.Colors.surfaceHighlight)
                    .overlay(ProgressView())
            }
        }
        .onAppear { loadImage() }
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { result, _ in
            if let result = result { self.image = result }
        }
    }
}

struct RecordingGalleryView: View {
    @StateObject private var viewModel = GalleryViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gallery")
                                .font(DesignSystem.Typography.largeTitle)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("\(viewModel.filteredVideos.count) Recorded Takes")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .tracking(1.0)
                        }
                        .padding(.top, 40)
                        
                        // Asymmetrical Filter Row
                        HStack(spacing: 8) {
                            Button(action: { viewModel.loadVideos() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                    Text("Filter")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .glassPanel(cornerRadius: 12)
                            }
                            
                            Button(action: openPhotosApp) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundColor(DesignSystem.Colors.secondary)
                                    Text("Date")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .glassPanel(cornerRadius: 12)
                            }
                            
                            Spacer()
                            
                            // Search bar taking remaining space
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                TextField("Search scripts...", text: $viewModel.searchText)
                                    .font(.system(size: 14))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .submitLabel(.search)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(DesignSystem.Colors.surfaceHighest)
                            .cornerRadius(12)
                            .frame(maxWidth: 240)
                        }
                        
                        // 2-Column Grid
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 24) {
                            ForEach(viewModel.filteredVideos) { video in
                                Button(action: { openVideo(video.phAsset) }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        
                                        // Card Image Container
                                        ZStack {
                                            GeometryReader { geo in
                                                PHAssetThumbnailView(asset: video.phAsset, size: CGSize(width: geo.size.width * 2, height: geo.size.width * 2 * (9/16)))
                                            }
                                            .aspectRatio(16/9, contentMode: .fill)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                            )
                                            
                                            // Badges
                                            VStack {
                                                HStack {
                                                    Text("\(video.qualityString) • 60FPS")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(DesignSystem.Colors.secondary)
                                                        .tracking(1.0)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .glassPanel(cornerRadius: 4)
                                                    Spacer()
                                                }
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Text(video.durationString)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.black.opacity(0.8))
                                                        .cornerRadius(8)
                                                }
                                            }
                                            .padding(12)
                                            
                                            // Play Overlay
                                            Circle()
                                                .fill(DesignSystem.Colors.accentContainer.opacity(0.2))
                                                .frame(width: 48, height: 48)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle().stroke(DesignSystem.Colors.accentContainer.opacity(0.4), lineWidth: 1)
                                                )
                                                .overlay(
                                                    Image(systemName: "play.fill")
                                                        .foregroundColor(DesignSystem.Colors.accent)
                                                )
                                        }
                                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                                        
                                        // Metadata below card
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(video.title)
                                                    .font(DesignSystem.Typography.headline)
                                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                                    .lineLimit(1)
                                                
                                                Text(video.creationDateString)
                                                    .font(DesignSystem.Typography.label)
                                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                            }
                                            Spacer()
                                            Button(action: {}) {
                                                Image(systemName: "ellipsis")
                                                    .rotationEffect(.degrees(90))
                                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                    .padding(.bottom, 120) // Extra padding for custom floating tab bar scroll clearance
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.requestPermissionAndLoad()
            }
            .fullScreenCover(isPresented: $viewModel.isPlayingVideo) {
                if let url = viewModel.selectedVideoURL {
                    NativeVideoPlayerView(url: url)
                }
            }
        }
    }
    
    private func openVideo(_ asset: PHAsset) {
        viewModel.playVideo(asset)
    }
    
    private func openPhotosApp() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}

struct NativeVideoPlayerView: View {
    let url: URL
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            }
            
            HStack {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.white.opacity(0.8))
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.white.opacity(0.8))
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
            }
            .padding()
        }
        .onAppear {
            self.player = AVPlayer(url: url)
        }
    }
}
