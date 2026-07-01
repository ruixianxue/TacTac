import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Welcome to\nTacTac")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            Text("Your spatial memory.\nPowered by your voice.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "mic.fill",
                    title: "Native Siri Support",
                    subtitle: "Ask Siri where your things are, without opening the app."
                )
                FeatureRow(
                    icon: "mappin.and.ellipse",
                    title: "Spatial Memory",
                    subtitle: "Replace physical trackers with the precision of language."
                )
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "Complete Privacy",
                    subtitle: "Your memories are protected with secure on-device data handling."
                )
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            
            Spacer()
            
            Text("TacTac needs location access to spatially anchor your items.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // Continue button
            Button(action: {
                TacLocationService.shared.requestPermissionIfNeeded()

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    hasCompletedOnboarding = true
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
    }
}

// Extracted row component to keep the code tidy
struct FeatureRow: View {
    var icon: String
    var title: String
    var subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
