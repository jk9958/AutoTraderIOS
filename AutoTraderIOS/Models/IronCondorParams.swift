import Foundation

struct IronCondorParams: Codable {
    var expiry: String
    var instrument: String
    var lots: Int
    var spreadPts: Int
    var wingPts: Int
    var profitTarget: Double
    var slMultiplier: Double
    var entryStart: String
    var entryCutoff: String
    var eodExit: String
    var dryRun: Bool

    static let defaultValues = IronCondorParams(
        expiry: "",
        instrument: "nifty",
        lots: 1,
        spreadPts: 400,
        wingPts: 200,
        profitTarget: 0.50,
        slMultiplier: 1.0,
        entryStart: "09:30",
        entryCutoff: "11:00",
        eodExit: "15:15",
        dryRun: true
    )

    static let userDefaultsKey = "ironCondorParams"

    static func load() -> IronCondorParams {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let params = try? JSONDecoder().decode(IronCondorParams.self, from: data) else {
            return defaultValues
        }
        return params
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: IronCondorParams.userDefaultsKey)
        }
    }

    func toRequestBody() -> [String: Any] {
        return [
            "expiry": expiry,
            "instrument": instrument,
            "lots": lots,
            "spread_pts": spreadPts,
            "wing_pts": wingPts,
            "profit_target": profitTarget,
            "sl_multiplier": slMultiplier,
            "entry_start": entryStart,
            "entry_cutoff": entryCutoff,
            "eod_exit": eodExit,
            "dry_run": dryRun
        ]
    }
}
