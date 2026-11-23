import SwiftUI

/// Collapsed island: one reading on each side of the camera, leaving the
/// middle empty so nothing is drawn behind the notch itself.
struct IslandCompactView: View {
  let payload: IslandPayload
  let geometry: NotchGeometry

  var body: some View {
    HStack(spacing: 0) {
      wing(payload.primary, alignment: .leading)
      Spacer(minLength: geometry.notchWidth)
      wing(payload.secondary, alignment: .trailing)
    }
    .padding(.horizontal, 14)
    .frame(height: geometry.height)
  }

  @ViewBuilder
  private func wing(_ reading: IslandReading?, alignment: HorizontalAlignment) -> some View {
    if let reading = reading {
      HStack(spacing: 6) {
        MeterRing(ratio: reading.ratio, level: reading.level, symbol: reading.symbol,
                  lineWidth: 2, iconScale: 0.45)
          .frame(width: geometry.height * 0.6, height: geometry.height * 0.6)
        Text(reading.value)
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundColor(reading.level == .normal
                           ? IslandPalette.primaryText
                           : IslandPalette.accent(reading.level))
          .lineLimit(1)
          .fixedSize()
      }
      .frame(width: NotchGeometry.wingWidth - 14,
             alignment: alignment == .leading ? .leading : .trailing)
      .help("\(reading.label): \(reading.value)")
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(reading.label) \(reading.value)")
    } else {
      ProgressView()
        .scaleEffect(0.45)
        .frame(width: NotchGeometry.wingWidth - 14, height: geometry.height)
    }
  }
}
