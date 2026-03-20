import SwiftUI
import Photos
import AVKit
import CoreData

struct VideoAsset: Identifiable {
    var id: String { phAsset.localIdentifier }
    let phAsset: PHAsset
    var title: String
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            #if targetEnvironment(simulator)
            DispatchQueue.main.async {
                self?.permissionGranted = true
                self?.loadVideos()
            }
            #else
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            
            if status == .authorized || status == .limited {
                DispatchQueue.main.async {
                    self?.permissionGranted = true
                    self?.loadVideos()
                }
            } else if status == .notDetermined {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    DispatchQueue.main.async {
                        if newStatus == .authorized || newStatus == .limited {
                            self?.permissionGranted = true
                            self?.loadVideos()
                        }
                    }
                }
            }
            #endif
        }
    }
    
    func loadVideos() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let loadStart = CFAbsoluteTimeGetCurrent()
            
            // 1. Fetch CoreData map for explicitly recorded videos
            let metaPayload = VideoMetadataCache.shared.getAllMetadata()
            let titleMap = Dictionary(uniqueKeysWithValues: metaPayload.map { ($0.localIdentifier, $0.title ?? "Recording") })
            let identifiers = metaPayload.map { $0.localIdentifier }
            
            guard !identifiers.isEmpty else {
                DispatchQueue.main.async { self.videos = [] }
                return
            }
            
            // 2. Fetch EXACT assets from camera roll using CoreData identifiers (No fallback scans needed)
            let fetchOptions = PHFetchOptions()
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: fetchOptions)
            
            var initialVideos: [VideoAsset] = []
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy • HH:mm"
            
            fetchResult.enumerateObjects { (asset, _, _) in
                guard asset.mediaType == .video else { return }
                
                let durationString = self.formatDuration(asset.duration)
                let dateString = asset.creationDate.map { dateFormatter.string(from: $0) } ?? "Unknown Date"
                let quality = "\(asset.pixelHeight)P"
                
                initialVideos.append(VideoAsset(
                    phAsset: asset,
                    title: titleMap[asset.localIdentifier] ?? "GoPrompt Recording",
                    durationString: durationString,
                    creationDateString: dateString,
                    qualityString: quality
                ))
            }
            
            // Sort by freshest recordings first
            initialVideos.sort { ($0.phAsset.creationDate ?? Date.distantPast) > ($1.phAsset.creationDate ?? Date.distantPast) }
            
            // Update UI
            DispatchQueue.main.async {
                self.videos = initialVideos
            }
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
        DispatchQueue.global(qos: .userInitiated).async {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.isSynchronous = false // CRITICAL: Stop 10s UI thread locks downloading massive poster frames!
            
            manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { result, _ in
                DispatchQueue.main.async {
                    if let result = result { self.image = result }
                }
            }
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
                        
                        // Top Nav Bar
                        HStack {
                            Spacer()
                            Text("GOPROMPT")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.white)
                                .tracking(2.0)
                            Spacer()
                        }
                        .padding(.top, 16)
                        .overlay(
                            HStack {
                                Spacer()
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.7))
                            }
                            .padding(.top, 16)
                        )
                        
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Gallery")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(viewModel.filteredVideos.count) Recorded Takes")
                                .font(.system(size: 15))
                                .foregroundColor(Color(white: 0.6))
                        }
                        .padding(.top, 20)
                        
                        // Filters
                        HStack(spacing: 12) {
                            Button(action: { viewModel.loadVideos() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(red: 0.89, green: 0.76, blue: 0.44)) // Gold tint
                                    Text("Filter")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(white: 0.15))
                                .cornerRadius(12)
                            }
                            
                            Button(action: openPhotosApp) {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(red: 0.89, green: 0.76, blue: 0.44)) // Gold tint
                                    Text("Date")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(white: 0.15))
                                .cornerRadius(12)
                            }
                            
                            Spacer()
                        }
                        
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(white: 0.6))
                            TextField("Search scripts...", text: $viewModel.searchText)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .submitLabel(.search)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.1))
                        .cornerRadius(12)
                        
                        // 1-Column Feed
                        LazyVStack(spacing: 32) {
                            ForEach(viewModel.filteredVideos) { video in
                                Button(action: { openVideo(video.phAsset) }) {
                                    VStack(alignment: .leading, spacing: 14) {
                                        // Card Image Container
                                        ZStack {
                                            GeometryReader { geo in
                                                PHAssetThumbnailView(asset: video.phAsset, size: CGSize(width: geo.size.width * 2, height: geo.size.width * 2 * (9/16)))
                                            }
                                            .aspectRatio(16/9, contentMode: .fill)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            .cornerRadius(16)
                                            
                                            // Badges
                                            VStack {
                                                HStack {
                                                    Text("\(video.qualityString) • 60FPS")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(Color(red: 0.89, green: 0.76, blue: 0.44))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.black.opacity(0.6))
                                                        .cornerRadius(6)
                                                    Spacer()
                                                }
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Text(video.durationString)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.black.opacity(0.8))
                                                        .cornerRadius(6)
                                                }
                                            }
                                            .padding(12)
                                        }
                                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                                        
                                        // Metadata below card
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(video.title)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                Text(video.creationDateString.replacingOccurrences(of: " • ", with: " • "))
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Color(white: 0.6))
                                            }
                                            Spacer()
                                            Button(action: {}) {
                                                Image(systemName: "ellipsis")
                                                    .rotationEffect(.degrees(90))
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(Color(white: 0.6))
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
                let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss.SSS"
                print("⏱️ [\(fmt.string(from: Date()))] [GALLERY] onAppear fired")
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
