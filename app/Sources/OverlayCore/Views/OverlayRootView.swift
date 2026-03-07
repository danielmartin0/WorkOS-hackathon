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
            adalSessionPicker
            terminalControls
            chat
            Text(viewModel.statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 500)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 10)
        .padding(20)
        .allowsHitTesting(true)
    }

    private var header: some View {
        HStack {
            Text("AdaL Overlay")
                .font(.headline)
            Spacer()
            Button("Refresh Windows") {
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

    private var adalSessionPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("AdaL Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh Sessions") {
                    viewModel.refreshAdalSessions()
                }
                .buttonStyle(.bordered)
            }

            Picker("AdaL Session", selection: Binding(
                get: { viewModel.selectedAdalSessionID ?? "" },
                set: { viewModel.selectAdalSession(id: $0) }
            )) {
                if viewModel.adalSessions.isEmpty {
                    Text("No adal sessions found").tag("")
                } else {
                    ForEach(viewModel.adalSessions) { session in
                        Text("\(session.title) • \(session.command)").tag(session.id)
                    }
                }
            }
            .labelsHidden()
        }
    }

    private var terminalControls: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Attach") { viewModel.attachSelectedSession() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.adalSessions.isEmpty)
                Button("Detach") { viewModel.detachSession() }
                    .buttonStyle(.bordered)
            }

            HStack {
                TextField("Message to selected adal terminal...", text: $viewModel.promptText)
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
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxHeight: 300)
    }
}
