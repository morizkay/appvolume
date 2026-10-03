import SwiftUI

struct AudioApplicationListView: View {
    let applications: [AudioApplicationViewModel]
    let devices: [AudioDevice]

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(applications) { application in
                AudioApplicationRow(viewModel: application, devices: devices)
                if application.id != applications.last?.id {
                    Divider()
                }
            }
        }
    }
}
