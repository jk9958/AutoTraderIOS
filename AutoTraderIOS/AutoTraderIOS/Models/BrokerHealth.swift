import Foundation

/// `GET /api/v2/broker-health` →
/// `{ "ok": true, "data": { "fyers": {connected, token_set, token_preview}, ... } }`
/// Decoded with `.convertFromSnakeCase`.
struct BrokerHealthResponse: Decodable {
    let brokers: [BrokerStatus]

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: DynamicKey.self)
        // Preferred: nested under "data".
        if let dataKey = DynamicKey(stringValue: "data"),
           let map = try? root.nestedContainer(keyedBy: DynamicKey.self, forKey: dataKey) {
            brokers = Self.parseMap(map)
            return
        }
        // Fallback: top-level map of broker → status (skip scalar keys like "ok").
        brokers = Self.parseMap(root, skip: ["ok", "meta", "error"])
    }

    private static func parseMap(_ c: KeyedDecodingContainer<DynamicKey>, skip: Set<String> = []) -> [BrokerStatus] {
        var out: [BrokerStatus] = []
        for key in c.allKeys where !skip.contains(key.stringValue) {
            if var status = try? c.decode(BrokerStatus.self, forKey: key) {
                status.broker = status.broker ?? key.stringValue
                out.append(status)
            }
        }
        return out.sorted { ($0.broker ?? "") < ($1.broker ?? "") }
    }
}

struct BrokerStatus: Decodable, Identifiable, Hashable {
    var broker: String?
    let connected: Bool?
    let tokenSet: Bool?
    let tokenPreview: String?

    var id: String { broker ?? UUID().uuidString }

    var isValid: Bool { (connected ?? false) && (tokenSet ?? false) }
}

struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
