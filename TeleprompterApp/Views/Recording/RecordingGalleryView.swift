import SwiftUI

/// Gallery view to browse saved recordings 
/// Updated to match the high-fidelity native Stitch GoPrompt UI.
/// (Currently redirects to Photos app as videos are saved directly there)
struct RecordingGalleryView: View {
    
    // Mock data based on Stitch design to show the UI
    var mockVideos = [
        ("Quarterly Strategy V1", "Oct 24, 2023 • 14:20", "4K • 60FPS", "02:45", "https://lh3.googleusercontent.com/aida-public/AB6AXuBm4aOzh4dy55boIRsVY4h9DOabjXGjCzNeIPL7LaS0cXkOS_WzG0bnTmJireFeQto8JJUjdZQ8U8kXFC8NFcth8w2VqKa82Y1ky8suMdaoinZIKHqdW-O8_n1cRH8HpQfhGrFZiD6FK0hATrpF0Og4DLHtReU0wFlYC0YKk2F6p6ZFmGpwy-WCh56li8wkq1dY3BEiyj0OLuG8LS6GuwYmr-sInq70012e6LHHn-XlRBRLephEH1HKLUSACUAQZe14uq4hXdF6XJT7"),
        ("Product Reveal Teaser", "Oct 22, 2023 • 09:15", "1080P • 24FPS", "01:12", "https://lh3.googleusercontent.com/aida-public/AB6AXuCExMmVfpnKiNjZmkZ3_ifXSjCGSg1yhefjaHolDB0RWFlxzV-I9cS0aoic4HGIAgZ5S0rvIe6na4HFDg5fs_gLNBN5rOxu-FN8XHjrPSrBwPwQ5ufPfDLrC2EfA3NbB0vFMm9j7RT_7GGEAl4Dw812g-Rb5QOxtEgEkg0fZwwvxDcktByagj-NOH7tneewuS9Hps3tmkwYdPBmmRHNDdHT-isyvjq0AzK_zA4RN6hhBUQScWO3oD9totsbdEsjaL1uF_iQtm3CVwwY"),
        ("Internal Keynote Mockup", "Oct 19, 2023 • 18:45", "4K • 30FPS", "05:20", "https://lh3.googleusercontent.com/aida-public/AB6AXuBg-ANjrNkNCgA3-k82SkbHB4hyVSN2vQYKrmblKMDm9yrTpbed-3HMd_UVlbH6MhyBTTTWlCzQ3Hn_ZO-unWMh7t4I6Y3Eiae0ZFyoMcfF3ePjWqYmisjhxwLfTW_k0_5oFCeG16X4rX4sThisPGn7Cpqkc39GHycx-Wh5n0kWgSkMck2C0m3FmmNmRURiZzrXCym6m-sREfOj3qcjLI5nTt6RIVahygCRkJbSwu3WZXBTxLaBPko1H-IL0F-8CU9Hee2SofRWKPCh"),
        ("Social Ad Vertical", "Oct 15, 2023 • 11:00", "4K • 60FPS", "00:45", "https://lh3.googleusercontent.com/aida-public/AB6AXuC73FuUZitqcA2I-5vQj8eOHQUSAk6-xuKcj_7mx7KptNnEVPtiYD-ON2hiTHX0Kslxd5hT-t8S2j8Ja66iR0-juAN7RlUl5VptliCY6Hi3ceyyE4Iuv6rt1ZBPUdaCZ7PXg44TQWJL_dE3D46bAm368ZfDf92o0qPLaQsu65Wo86hAMtSxbcvxVumZCQ27-vXxkmbw55zzU7A6LPiwgIAWI6682-xowxDKuBiVWKDWUJEXOqpySj-AIERWzJvVHusV9bk0y_kEa412")
    ]
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Storage Notification Alert
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "photo.stack.fill")
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .font(.title3)
                                Text("Saved to Photos")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                Spacer()
                            }
                            Text("All your teleprompter recordings are automatically saved directly to your device's Photo Library in maximum quality. Tap any video to open.")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(DesignSystem.Colors.surfaceHighlight.opacity(0.8))
                        .cornerRadius(DesignSystem.Layout.cornerRadiusLarge)
                        .padding(.top, 24)
                        
                        // Gallery Header & Filters
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gallery")
                                    .font(DesignSystem.Typography.largeTitle)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                Text("\(mockVideos.count) Recorded Takes")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                    .tracking(1.0)
                            }
                            
                            // Controls
                            HStack(spacing: 8) {
                                Button(action: openPhotosApp) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "line.3.horizontal.decrease.circle")
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                        Text("Filter")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                                }
                                
                                Button(action: openPhotosApp) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.arrow.down.circle")
                                            .foregroundColor(DesignSystem.Colors.secondary)
                                        Text("Date")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .glassPanel(cornerRadius: DesignSystem.Layout.cornerRadiusStandard)
                                }
                                
                                Spacer()
                                
                                // Search mock
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                    Text("Search scripts...")
                                        .font(.system(size: 14))
                                        .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.5))
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(width: 160)
                                .background(DesignSystem.Colors.background)
                                .cornerRadius(DesignSystem.Layout.cornerRadiusStandard)
                            }
                        }
                        
                        // Recording Grid (2-column)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)], spacing: 24) {
                            ForEach(0..<mockVideos.count, id: \.self) { index in
                                let video = mockVideos[index]
                                
                                Button(action: openPhotosApp) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Video Thumbnail
                                        ZStack {
                                            AsyncImage(url: URL(string: video.4)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .opacity(0.8)
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(DesignSystem.Colors.surface)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .aspectRatio(16/9, contentMode: .fit)
                                            .cornerRadius(DesignSystem.Layout.cornerRadiusLarge)
                                            
                                            // Badges
                                            VStack {
                                                HStack {
                                                    Text(video.2)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(DesignSystem.Colors.secondary)
                                                        .tracking(1.0)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .glassPanel(cornerRadius: 6)
                                                    Spacer()
                                                }
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Text(video.3)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.black.opacity(0.8))
                                                        .cornerRadius(8)
                                                }
                                            }
                                            .padding(12)
                                            
                                            // Play Hint Mock
                                            Circle()
                                                .fill(DesignSystem.Colors.accent.opacity(0.2))
                                                .frame(width: 48, height: 48)
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(DesignSystem.Colors.accent.opacity(0.4), lineWidth: 1)
                                                )
                                                .overlay(
                                                    Image(systemName: "play.fill")
                                                        .foregroundColor(DesignSystem.Colors.accent)
                                                )
                                                .opacity(0) // Hover in native
                                        }
                                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                                        
                                        // Metadata
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(video.0)
                                                    .font(DesignSystem.Typography.headline)
                                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                                    .tracking(-0.5)
                                                
                                                Text(video.1)
                                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                            }
                                            Spacer()
                                            Image(systemName: "ellipsis")
                                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Layout.paddingLarge)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func openPhotosApp() {
        if let url = URL(string: "photos-redirect://") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    RecordingGalleryView()
}
