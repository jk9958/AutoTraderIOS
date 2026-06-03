import Foundation

struct MTMResponse: Codable {
    let marketOpen: Bool?   // decoded from "market_open" via convertFromSnakeCase
    let mtm: MTMData?
}

struct MTMData: Codable {
    let mtmInr: Double?
    let mtmPts: Double?
    let status: String?
    let spot: Double?
    let entrySpot: Double?
    let entryTime: String?
    let atm: Double?
    let netCredit: Double?
    let costToClose: Double?
    let profitTargetPts: Double?
    let slPts: Double?
    let lots: Int?
    let lotSize: Int?
    let shortCe: Double?
    let longCe: Double?
    let shortPe: Double?
    let longPe: Double?
    let timestamp: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        mtmInr = try Self.decodeDouble(container, "mtmInr", "mtm_inr")
        mtmPts = try Self.decodeDouble(container, "mtmPts", "mtm_pts")
        status = try Self.decodeString(container, "status")
        spot = try Self.decodeDouble(container, "spot")
        entrySpot = try Self.decodeDouble(container, "entrySpot", "entry_spot")
        entryTime = try Self.decodeString(container, "entryTime", "entry_time")
        atm = try Self.decodeDouble(container, "atm")
        netCredit = try Self.decodeDouble(container, "netCredit", "net_credit")
        costToClose = try Self.decodeDouble(container, "costToClose", "cost_to_close")
        profitTargetPts = try Self.decodeDouble(container, "profitTargetPts", "profit_target_pts")
        slPts = try Self.decodeDouble(container, "slPts", "sl_pts")
        lots = try Self.decodeInt(container, "lots")
        lotSize = try Self.decodeInt(container, "lotSize", "lot_size")
        shortCe = try Self.decodeDouble(container, "shortCe", "short_ce")
        longCe = try Self.decodeDouble(container, "longCe", "long_ce")
        shortPe = try Self.decodeDouble(container, "shortPe", "short_pe")
        longPe = try Self.decodeDouble(container, "longPe", "long_pe")
        timestamp = try Self.decodeString(container, "timestamp")
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<AnyCodingKey>, _ keys: String...) throws -> Double? {
        for key in keys {
            let codingKey = AnyCodingKey(stringValue: key)!
            if let doubleValue = try container.decodeIfPresent(Double.self, forKey: codingKey) {
                return doubleValue
            }
            if let stringValue = try container.decodeIfPresent(String.self, forKey: codingKey) {
                if let converted = Double(stringValue) {
                    return converted
                }
            }
        }
        return nil
    }

    private static func decodeString(_ container: KeyedDecodingContainer<AnyCodingKey>, _ keys: String...) throws -> String? {
        for key in keys {
            let codingKey = AnyCodingKey(stringValue: key)!
            if let value = try container.decodeIfPresent(String.self, forKey: codingKey) {
                return value
            }
        }
        return nil
    }

    private static func decodeInt(_ container: KeyedDecodingContainer<AnyCodingKey>, _ keys: String...) throws -> Int? {
        for key in keys {
            let codingKey = AnyCodingKey(stringValue: key)!
            if let value = try container.decodeIfPresent(Int.self, forKey: codingKey) {
                return value
            }
        }
        return nil
    }

    init(mtmInr: Double? = nil, mtmPts: Double? = nil, status: String? = nil, spot: Double? = nil, entrySpot: Double? = nil, entryTime: String? = nil, atm: Double? = nil, netCredit: Double? = nil, costToClose: Double? = nil, profitTargetPts: Double? = nil, slPts: Double? = nil, lots: Int? = nil, lotSize: Int? = nil, shortCe: Double? = nil, longCe: Double? = nil, shortPe: Double? = nil, longPe: Double? = nil, timestamp: String? = nil) {
        self.mtmInr = mtmInr
        self.mtmPts = mtmPts
        self.status = status
        self.spot = spot
        self.entrySpot = entrySpot
        self.entryTime = entryTime
        self.atm = atm
        self.netCredit = netCredit
        self.costToClose = costToClose
        self.profitTargetPts = profitTargetPts
        self.slPts = slPts
        self.lots = lots
        self.lotSize = lotSize
        self.shortCe = shortCe
        self.longCe = longCe
        self.shortPe = shortPe
        self.longPe = longPe
        self.timestamp = timestamp
    }
}

struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
