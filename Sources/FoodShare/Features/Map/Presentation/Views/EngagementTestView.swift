
#if !SKIP
import SwiftUI

struct EngagementTestView: View {
    @State private var testResult = "Not tested"
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Engagement RPC Test")
                .font(.title)

            Text(testResult)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(CornerRadius.small)

            Button("Test RPC Functions") {
                testRPCFunctions()
            }
            .disabled(isLoading)

            if isLoading {
                ProgressView()
            }
        }
        .padding()
    }

    private func testRPCFunctions() {
        isLoading = true
        testResult = "Testing RPC functions..."

        Task {
            do {
                let supabase = SupabaseManager.shared.client

                // Test 1: Check if toggle_like function exists with a test post ID
                print("🔍 Testing toggle_like RPC...")
                let response = try await supabase
                    .rpc("toggle_like", params: ["p_post_id": 999_999])
                    .execute()

                let responseString = String(data: response.data, encoding: .utf8) ?? "No data"
                print("✅ RPC Response: \(responseString)")

                await MainActor.run {
                    testResult = "✅ RPC functions exist!\nResponse: \(responseString)"
                    isLoading = false
                }
            } catch {
                print("❌ RPC Error: \(error)")
                await MainActor.run {
                    testResult = "❌ RPC Error: \(error.localizedDescription)\n\nThis means the RPC functions are missing from the database."
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    EngagementTestView()
}

#endif
