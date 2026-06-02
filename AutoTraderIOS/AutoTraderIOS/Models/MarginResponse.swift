struct MarginResponse: Decodable {
    let instrument: String
    let lots: Int
    let lotSize: Int
    let spot: Double
    let atm: Int
    let shortCe: Int
    let longCe: Int
    let shortPe: Int
    let longPe: Int
    let shortCeSym: String?
    let netCreditEst: Double
    let maxLossPts: Double
    let maxLossInr: Double
    let marginPerLot: Double
    let marginTotal: Double
}
