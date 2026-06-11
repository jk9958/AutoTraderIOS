import SwiftUI

struct RotateKeyView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SettingsVM()
    @Environment(\.dismiss) private var dismiss

    @State private var newKey = ""
    @State private var confirmShown = false

    var body: some View {
        Form {
            Section {
                SecureField("New API key", text: $newKey)
                    .textContentType(.newPassword)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("New Key")
            } footer: {
                Text("Minimum 12 characters. The new key takes effect on the server immediately.")
            }

            Section {
                Button {
                    confirmShown = true
                } label: {
                    HStack {
                        Label("Rotate Key", systemImage: "key.horizontal")
                        Spacer()
                        statusView
                    }
                }
                .disabled(newKey.trimmingCharacters(in: .whitespaces).count < 12 || vm.rotateState == .rotating)
            }
        }
        .navigationTitle("Rotate API Key")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Rotate the API key?",
            isPresented: $confirmShown,
            titleVisibility: .visible
        ) {
            Button("Rotate", role: .destructive) {
                Task {
                    await vm.rotate(newKey: newKey, appState: appState)
                    if vm.rotateState == .success { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The new key becomes active immediately. The app will start using it for all write requests.")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch vm.rotateState {
        case .idle:
            EmptyView()
        case .rotating:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure(let msg):
            Text(msg).font(.caption).foregroundStyle(.red).lineLimit(2)
        }
    }
}
