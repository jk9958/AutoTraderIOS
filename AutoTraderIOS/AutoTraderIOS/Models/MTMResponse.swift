import Foundation

struct MTMResponse: Codable {
    let mtm: MTMData?
}

struct MTMData: Codable {
    let mtmInr: Int?
    let mtmPts: Int?
    let status: String?
    let spot: Double?
    let entrySpot: Double?
    let netCredit: Int?
    let costToClose: Int?
    let profitTargetPts: Int?
    let slPts: Int?
    let lots: Int?
    let lotSize: Int?
    let shortCe: String?
    let longCe: String?
    let shortPe: String?
    let longPe: String?
    let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case mtmInr = "mtm_inr"
        case mtmPts = "mtm_pts"
        case status
        case spot
        case entrySpot = "entry_spot"
        case netCredit = "net_credit"
        case costToClose = "cost_to_close"
        case profitTargetPts = "profit_target_pts"
        case slPts = "sl_pts"
        case lots
        case lotSize = "lot_size"
        case shortCe = "short_ce"
        case longCe = "long_ce"
        case shortPe = "short_pe"
        case longPe = "long_pe"
        case timestamp
    }
}
