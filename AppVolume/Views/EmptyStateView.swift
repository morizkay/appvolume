import SwiftUI

struct EmptyStateView: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No active audio applications")
                .font(.headline)
            Text("Apps appear here when Core Audio reports an active output session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh", action: onRefresh)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding()
        .accessibilityElement(children: .combine)
    }
}
