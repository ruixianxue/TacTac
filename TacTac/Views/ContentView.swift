import SwiftUI
import FoundationModels

struct ContentView: View {
    @State private var result = "等待中..."

    var body: some View {
        VStack {
            Text(result)
                .padding()
            Button("测试 Foundation Models") {
                Task {
                    await testFM()
                }
            }
        }
    }

    func testFM() async {
        let session = LanguageModelSession()
        do {
            let response = try await session.respond(
                to: "说一个字：好"
            )
            result = response.content
        } catch {
            result = "失败：\(error)"
        }
    }
}
