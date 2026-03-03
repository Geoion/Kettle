import SwiftUI

struct SearchToolbar: View {
    @Binding var text: String
    var placeholder: String = L("Search...")

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .disableAutocorrection(true)
                .textContentType(.none)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LastUpdatedLabel: View {
    let date: Date?

    var body: some View {
        Group {
            if let date {
                Text(String(format: L("last.updated"), date.relativeFormatted))
            } else {
                Text(L("last.updated.never"))
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .monospacedDigit()
    }
}

private extension Date {
    var relativeFormatted: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 {
            return L("last.updated.just.now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

struct StatusFooter: View {
    let count: Int
    let itemLabel: String
    let lastUpdate: Date?

    var body: some View {
        HStack(spacing: 8) {
            Text("\(count) \(itemLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if let date = lastUpdate {
                Text(String(format: L("last.updated"), date.relativeFormatted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
