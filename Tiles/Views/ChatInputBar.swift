import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isProcessing: Bool
    let onSubmit: () -> Void

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("chat.placeholder", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .onSubmit(onSubmit)

            if isProcessing {
                ProgressView()
                    .frame(width: 36, height: 36)
            } else {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(isEmpty ? Color.secondary : Color.accentColor)
                }
                .disabled(isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
