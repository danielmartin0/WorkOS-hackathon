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
            statusBar
        }
        .padding(16)
        .frame(width: 520)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.10, blue: 0.16).opacity(0.90),
                        Color(red: 0.11, green: 0.22, blue: 0.30).opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.16, green: 0.42, blue: 0.52).opacity(0.30),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 300
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
        .padding(20)
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AdaL Terminal Bridge")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Attach to active adal terminals")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Button("Refresh Windows") {
                viewModel.refreshWindows()
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
        .allowsHitTesting(true)
    }

    private var windowPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Target Window")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            Picker("Target Window", selection: Binding(
                get: { viewModel.selectedWindowID ?? 0 },
                set: { viewModel.chooseWindow(windowID: $0) }
            )) {
                ForEach(viewModel.availableWindows) { window in
                    Text(window.displayName).tag(window.id)
                }
            }
            .labelsHidden()
            .tint(.white)
        }
        .allowsHitTesting(true)
    }

    private var adalSessionPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("AdaL Session")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Button("Refresh Sessions") {
                    viewModel.refreshAdalSessions()
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
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
            .tint(.white)
        }
        .allowsHitTesting(true)
    }

    private var terminalControls: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Attach") { viewModel.attachSelectedSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.adalSessions.isEmpty)
                Button("Detach") { viewModel.detachSession() }
                    .buttonStyle(.bordered)
                    .tint(.orange)
            }

            HStack {
                TextField("Message to selected adal terminal...", text: $viewModel.promptText)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    viewModel.sendPrompt()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .keyboardShortcut(.return)
            }
        }
        .allowsHitTesting(true)
    }

    private var chat: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(viewModel.chatLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxHeight: 300)
        .padding(10)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(true)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.statusLine.localizedCaseInsensitiveContains("failed") ? .red : .green)
                .frame(width: 8, height: 8)
            Text(viewModel.statusLine)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
        }
    }
}
