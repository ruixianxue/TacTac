import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 标题部分
            Text("Bienvenue sur\nTacTac")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            Text("Votre mémoire spatiale.\nPortée par votre voix.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // 核心功能介绍 (原生视觉风格)
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "mic.fill",
                    title: "Siri-Native",
                    subtitle: "Demandez à Siri où sont vos affaires, sans écran."
                )
                FeatureRow(
                    icon: "mappin.and.ellipse",
                    title: "Mémoire Spatiale",
                    subtitle: "Remplacez les capteurs physiques par la précision du langage."
                )
                FeatureRow(
                    icon: "lock.shield.fill",
                    title: "Confidentialité Absolue",
                    subtitle: "Données inaccessibles, même par Apple."
                )
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            
            Spacer()
            
            Text("TacTac nécessite l'accès au microphone et à la localisation pour l'ancrage spatial de vos objets.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // 继续按钮
            Button(action: {
                TacLocationService.shared.requestPermissionIfNeeded()

                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    hasCompletedOnboarding = true
                }
            }) {
                Text("Continuer")
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

// 提取的行组件，保持代码整洁
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
