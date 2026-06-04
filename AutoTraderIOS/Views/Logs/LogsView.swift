import SwiftUI

struct LogsView: View {
    @EnvironmentObject var apiClient: APIClient
    @StateObject private var viewModel = LogsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Controls bar
                    ControlsBar(viewModel: viewModel, apiClient: apiClient)

                    Divider().background(Theme.divider)

                    if viewModel.lines.isEmpty {
                        EmptyLogsView(
                            hasError: viewModel.errorMessage != nil,
                            errorMessage: viewModel.errorMessage
                        )
                    } else {
                        LogScrollView(lines: viewModel.lines)
                    }

                    // Source caption
                    if !viewModel.source.isEmpty {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                            Text("Source: \(viewModel.source)")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(viewModel.lines.count) lines")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Theme.card)
                    }
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                viewModel.startPolling(using: apiClient)
                Task { await viewModel.refresh(using: apiClient) }
            case .background, .inactive:
                viewModel.stopPolling()
            @unknown default:
                break
            }
        }
        .onAppear {
            viewModel.startPolling(using: apiClient)
            if !viewModel.hasLoaded {
                Task { await viewModel.refresh(using: apiClient) }
            }
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

private struct ControlsBar: View {
    @ObservedObject var viewModel: LogsViewModel
    let apiClient: APIClient

    var body: some View {
        HStack(spacing: 12) {
            // Pause/Resume
            Button {
                viewModel.togglePause()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(viewModel.isPaused ? Theme.green : Theme.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((viewModel.isPaused ? Theme.green : Theme.orange).opacity(0.15))
                .cornerRadius(8)
            }

            // Manual refresh
            Button {
                Task { await viewModel.refresh(using: apiClient) }
            } label: {
                HStack(spacing: 4) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.blue))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text("Refresh")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(Theme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.blue.opacity(0.15))
                .cornerRadius(8)
            }
            .disabled(viewModel.isLoading)

            Spacer()

            // Line count picker
            Menu {
                ForEach(viewModel.lineCountOptions, id: \.self) { count in
                    Button("\(count) lines") {
                        viewModel.changeLineCount(count, using: apiClient)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(viewModel.selectedLineCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Theme.text)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.card)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }
}

private struct LogScrollView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(lineColor(for: line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 1)
                            .id(index)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Theme.background)
            .onChange(of: lines.count) { _ in
                if let lastIndex = lines.indices.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastIndex = lines.indices.last {
                    proxy.scrollTo(lastIndex, anchor: .bottom)
                }
            }
        }
    }

    private func lineColor(for line: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("exception") || lower.contains("fail") {
            return Theme.red
        }
        if lower.contains("warn") || lower.contains("warning") {
            return Theme.orange
        }
        if lower.contains("entry") || lower.contains("exit") || lower.contains("started") {
            return Theme.green
        }
        return Theme.text
    }
}

private struct EmptyLogsView: View {
    let hasError: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasError ? "wifi.slash" : "doc.text")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(Theme.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("No logs yet.")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary)
                Text("Start a trading engine to see output here.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}
