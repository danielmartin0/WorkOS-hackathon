import SwiftUI

public struct OverlayRootView: View {
    @ObservedObject private var viewModel: OverlayViewModel

    public init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        panel
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            windowPicker
            controls
            chat
            if let warning = viewModel.permissionWarning {
                Text(warning)
                    .font(.footnote)
                    .foregroundStyle(.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(viewModel.statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 10)
        .padding(20)
        .allowsHitTesting(true)
    }

    private var header: some View {
        HStack {
            Text("Game Overlay")
                .font(.headline)
            Spacer()
            Button("Refresh") {
                viewModel.refreshWindows()
            }
            .buttonStyle(.bordered)
        }
    }

    private var windowPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Target Window")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Target Window", selection: Binding(
                get: { viewModel.selectedWindowID ?? 0 },
                set: { viewModel.chooseWindow(windowID: $0) }
            )) {
                ForEach(viewModel.availableWindows) { window in
                    Text(window.displayName).tag(window.id)
                }
            }
            .labelsHidden()
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Capture now") { viewModel.captureNow() }
                    .buttonStyle(.borderedProminent)
                Button(viewModel.periodicCaptureEnabled ? "Stop periodic" : "Start periodic") {
                    viewModel.togglePeriodicCapture()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                TextField("Ask the agent...", text: $viewModel.promptText)
                Button("Send") {
                    viewModel.sendPrompt()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
    }

    private var chat: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(viewModel.chatLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxHeight: 220)
    }
}
