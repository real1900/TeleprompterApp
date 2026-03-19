import SwiftUI

/// Gallery view to browse saved recordings 
/// (Currently redirects to Photos app as videos are saved directly there)
struct RecordingGalleryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        ContentUnavailableView {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.stack.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(DesignSystem.Colors.accent)
                                
                                Text("Saved to Photos")
                                    .font(DesignSystem.Typography.title)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                            }
                        } description: {
                            Text("All your teleprompter recordings are automatically saved directly to your device's Photo Library in maximum quality.")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                        } actions: {
                            Button {
                                if let url = URL(string: "photos-redirect://") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Open Photos Library")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(DesignSystem.Colors.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusStandard))
                                    .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 24)
                        }
                        .padding(.top, 80)
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    RecordingGalleryView()
}
