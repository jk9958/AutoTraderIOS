import Foundation

struct LogsResponse: Codable {
    let source: String?   // /logs has it; /logs/api does not
    let lines: [String]
}

/// `GET /logs/files` → list of available engine log files.
/// Decoded with `.convertFromSnakeCase` — camelCase, NO CodingKeys.
struct LogFilesResponse: Decodable {
    let files: [LogFile]

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let arr = try? single.decode([LogFile].self) {
            files = arr
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        files = try keyed.decodeIfPresent([LogFile].self, forKey: .files) ?? []
    }

    enum CodingKeys: String, CodingKey { case files }
}

struct LogFile: Decodable, Identifiable, Hashable {
    let name: String
    let sizeKb: Double?
    let compressed: Bool?
    let logDate: String?   // "YYYYMMDD"

    var id: String { name }

    var sizeLabel: String {
        guard let kb = sizeKb else { return "" }
        if kb >= 1024 { return String(format: "%.1f MB", kb / 1024) }
        return String(format: "%.0f KB", kb)
    }
}

/// `GET /logs/file?name=&lines=` → contents of a single file.
struct LogFileResponse: Decodable {
    let name: String?
    let lines: [String]

    init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        name = try keyed.decodeIfPresent(String.self, forKey: .name)
        lines = try keyed.decodeIfPresent([String].self, forKey: .lines) ?? []
    }

    enum CodingKeys: String, CodingKey { case name, lines }
}
