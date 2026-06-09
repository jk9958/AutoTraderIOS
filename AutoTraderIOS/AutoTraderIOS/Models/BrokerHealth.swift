import Foundation

/// `GET /api/v2/broker-health` → per-broker token status.
/// Server shape unverified; modelled defensively (everything optional) so an
/// unexpected payload still decodes. Decoded with `.convertFromSnakeCase`.
struct BrokerHealthResponse: Decodable {
    let brokers: [BrokerStatus]

    init(from decoder: Decoder) throws {
        // Accept either { "brokers": {fyers: {...}} }, { "brokers": [...] },
        // or a bare top-level map { fyers: {...}, kite: {...} }.
        if let keyed = try? decoder.container(keyedBy: DynamicKey.self),
           keyed.contains(DynamicKey(stringValue: "brokers")!) {
            if let nested = try? keyed.nestedContainer(keyedBy: DynamicKey.self, forKey: DynamicKey(stringValue: "brokers")!) {
                brokers = Self.parseMap(nested)
                return
            }
            if let arr = try? keyed.decode([BrokerStatus].self, forKey: DynamicKey(stringValue: "brokers")!) {
                brokers = arr
                return
            }
        }
        if let map = try? decoder.container(keyedBy: DynamicKey.self) {
            brokers = Self.parseMap(map)
            return
        }
        brokers = []
    }

    private static func parseMap(_ c: KeyedDecodingContainer<DynamicKey>) -> [BrokerStatus] {
        var out: [BrokerStatus] = []
        for key in c.allKeys {
            if var status = try? c.decode(BrokerStatus.self, forKey: key) {
                status.broker = status.broker ?? key.stringValue
                out.append(status)
            }
        }
        return out
    }
}

struct BrokerStatus: Decodable, Identifiable, Hashable {
    var broker: String?
    let valid: Bool?
    let status: String?
    let expiresAt: String?
    let updatedAt: String?
    let message: String?

    var id: String { broker ?? UUID().uuidString }

    var isValid: Bool {
        if let valid { return valid }
        return (status ?? "").localizedCaseInsensitiveContains("valid")
    }
}

struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
