import SwiftUI

/// Colours of the island. The body is always pure black so it blends with
/// the camera housing; only accents change with the severity of a reading.
enum IslandPalette {
  static let body = Color.black
  static let primaryText = Color.white
  static let secondaryText = Color.white.opacity(0.55)
  static let track = Color.white.opacity(0.12)
  static let hairline = Color.white.opacity(0.08)

  static func accent(_ level: IslandLevel) -> Color {
    switch level {
    case .normal: return Color(red: 0.36, green: 0.86, blue: 0.62)
    case .elevated: return Color(red: 1.0, green: 0.74, blue: 0.27)
    case .critical: return Color(red: 1.0, green: 0.36, blue: 0.36)
    }
  }
}
