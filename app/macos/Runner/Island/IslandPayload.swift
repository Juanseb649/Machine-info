import Foundation

/// Severity sent by Dart for each reading and for the island as a whole.
enum IslandLevel: String {
  case normal, elevated, critical
}

/// One reading already formatted on the Dart side.
struct IslandReading: Identifiable, Equatable {
  let key: String
  let label: String
  let value: String
  let detail: String
  let ratio: Double
  let level: IslandLevel
  let symbol: String

  var id: String { key }

  init?(_ raw: Any?) {
    guard let map = raw as? [String: Any], let key = map["key"] as? String else { return nil }
    self.key = key
    label = map["label"] as? String ?? ""
    value = map["value"] as? String ?? "–"
    detail = map["detail"] as? String ?? ""
    ratio = min(max((map["ratio"] as? NSNumber)?.doubleValue ?? 0, 0), 1)
    level = IslandLevel(rawValue: map["level"] as? String ?? "") ?? .normal
    symbol = map["symbol"] as? String ?? "gauge"
  }
}

/// Everything the island draws, decoded from the `update` channel call.
struct IslandPayload: Equatable {
  var title = "Machine Info"
  var hostname = ""
  var uptime = ""
  var updatedAt = ""
  var level: IslandLevel = .normal
  var primary: IslandReading?
  var secondary: IslandReading?
  var readings: [IslandReading] = []

  static let empty = IslandPayload()

  init() {}

  init(_ raw: Any?) {
    guard let map = raw as? [String: Any] else { return }
    title = map["title"] as? String ?? title
    hostname = map["hostname"] as? String ?? ""
    uptime = map["uptime"] as? String ?? ""
    updatedAt = map["updatedAt"] as? String ?? ""
    level = IslandLevel(rawValue: map["level"] as? String ?? "") ?? .normal
    primary = IslandReading(map["primary"])
    secondary = IslandReading(map["secondary"])
    readings = (map["readings"] as? [Any] ?? []).compactMap(IslandReading.init)
  }
}
