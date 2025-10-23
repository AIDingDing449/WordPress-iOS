import SwiftUI

struct ConversationBotIntro: View {
    let currentUser: SupportUser

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Blue sparkle/star icon
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 16) {
                // Greeting with wave emoji
                HStack {
                    Text("Howdy \(currentUser.username)!")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("👋")
                        .font(.title2)
                }

                // Description text
                Text("I'm your personal AI assistant. I can help with any questions about your site or account.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ConversationBotIntro(currentUser: SupportDataProvider.supportUser)
        .background(Color(.systemBackground))
}
