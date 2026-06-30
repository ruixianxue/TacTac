import SwiftUI
import FoundationModels

struct ContentView: View {
    @State private var result = "Waiting..."

    var body: some View {
        VStack {
            Text(result)
                .padding()
            Button("Test Foundation Models") {
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
                to: "Say one word: good"
            )
            result = response.content
        } catch {
            result = "Failed: \(error)"
        }
    }
}
