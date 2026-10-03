import SwiftUI

struct OutputDevicePicker: View {
    let devices: [AudioDevice]
    let selectedDeviceID: String
    let isEnabled: Bool
    let onSelection: (String) -> Void

    var body: some View {
        Picker("Output", selection: Binding(
            get: { selectedDeviceID },
            set: onSelection
        )) {
            if devices.isEmpty {
                Text("No output device").tag("")
            } else {
                ForEach(devices) { device in
                    HStack {
                        Text(device.name)
                        if device.isVirtual {
                            Text("Virtual").foregroundStyle(.secondary)
                        }
                    }
                    .tag(device.uid)
                }
            }
        }
        .pickerStyle(.menu)
        .disabled(!isEnabled || devices.isEmpty)
        .accessibilityLabel("Output device")
    }
}
