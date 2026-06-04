import SwiftUI

@MainActor
final class TradeViewModel: ObservableObject {
    @Published var ironCondorParams: IronCondorParams = IronCondorParams.load()
    @Published var scalpingDryRun: Bool = true
    @Published var optionsDryRun: Bool = true

    @Published var isLaunchingIronCondor: Bool = false
    @Published var isLaunchingScalping: Bool = false
    @Published var isLaunchingOptions: Bool = false

    @Published var showLiveConfirmationIronCondor: Bool = false
    @Published var showLiveConfirmationScalping: Bool = false
    @Published var showLiveConfirmationOptions: Bool = false

    @Published var showConflictAlert: Bool = false
    @Published var conflictMessage: String = ""

    @Published var showSuccessBanner: Bool = false
    @Published var successMessage: String = ""

    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""

    @Published var validationErrors: [String: String] = [:]

    @Published var currentStatus: ServerStatus? = nil

    // Stored reference set once by the owning View via .task or .onAppear
    var apiClient: APIClient?

    var engineIsRunning: Bool {
        currentStatus?.running == true
    }

    func updateExpiry(from status: ServerStatus?) {
        guard let status else { return }
        if ironCondorParams.expiry.isEmpty {
            ironCondorParams.expiry = status.nextExpiry
        }
    }

    // MARK: - Iron Condor

    func requestLaunchIronCondor() {
        if !ironCondorParams.dryRun {
            Haptics.warning()
            showLiveConfirmationIronCondor = true
        } else {
            Task { await launchIronCondor() }
        }
    }

    func launchIronCondor() async {
        guard let apiClient else { return }
        validationErrors = [:]
        isLaunchingIronCondor = true
        defer { isLaunchingIronCondor = false }
        ironCondorParams.save()
        do {
            let response = try await apiClient.startIronCondor(params: ironCondorParams)
            Haptics.success()
            successMessage = "Iron Condor started: \(response.engine ?? "engine")"
            showSuccessBanner = true
        } catch let error as APIError {
            handleLaunchError(error)
        } catch {
            Haptics.error()
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    // MARK: - Scalping

    func requestLaunchScalping() {
        if !scalpingDryRun {
            Haptics.warning()
            showLiveConfirmationScalping = true
        } else {
            Task { await launchScalping() }
        }
    }

    func launchScalping() async {
        guard let apiClient else { return }
        isLaunchingScalping = true
        defer { isLaunchingScalping = false }
        do {
            let response = try await apiClient.startScalping(dryRun: scalpingDryRun)
            Haptics.success()
            successMessage = "Scalping started: \(response.engine ?? "engine")"
            showSuccessBanner = true
        } catch let error as APIError {
            handleLaunchError(error)
        } catch {
            Haptics.error()
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    // MARK: - Options

    func requestLaunchOptions() {
        if !optionsDryRun {
            Haptics.warning()
            showLiveConfirmationOptions = true
        } else {
            Task { await launchOptions() }
        }
    }

    func launchOptions() async {
        guard let apiClient else { return }
        isLaunchingOptions = true
        defer { isLaunchingOptions = false }
        do {
            let response = try await apiClient.startOptions(dryRun: optionsDryRun)
            Haptics.success()
            successMessage = "Options started: \(response.engine ?? "engine")"
            showSuccessBanner = true
        } catch let error as APIError {
            handleLaunchError(error)
        } catch {
            Haptics.error()
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    // MARK: - Error Handling

    private func handleLaunchError(_ error: APIError) {
        switch error {
        case .conflict(let msg):
            conflictMessage = msg
            showConflictAlert = true
        case .validationErrors(let errors):
            Haptics.error()
            validationErrors = Dictionary(
                uniqueKeysWithValues: errors.compactMap { detail -> (String, String)? in
                    guard let field = detail.fieldName else { return nil }
                    return (field, detail.msg)
                }
            )
            if validationErrors.isEmpty {
                errorMessage = errors.map { $0.msg }.joined(separator: "\n")
                showErrorAlert = true
            }
        default:
            Haptics.error()
            errorMessage = error.errorDescription ?? "An unexpected error occurred."
            showErrorAlert = true
        }
    }
}
