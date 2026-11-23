import SwiftUI

/// Circular gauge used by both island states: a faint track, an accent arc
/// for the ratio and an SF Symbol in the middle.
struct MeterRing: View {
  let ratio: Double
  let level: IslandLevel
  let symbol: String
  var lineWidth: CGFloat = 3
  var iconScale: CGFloat = 0.42

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      ZStack {
        Circle()
          .stroke(IslandPalette.track, lineWidth: lineWidth)
        Circle()
          .trim(from: 0, to: CGFloat(max(ratio, 0.02)))
          .stroke(IslandPalette.accent(level),
                  style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .animation(.easeOut(duration: 0.6), value: ratio)
        Image(systemName: symbol)
          .font(.system(size: side * iconScale, weight: .semibold))
          .foregroundColor(IslandPalette.primaryText.opacity(0.9))
      }
      .frame(width: side, height: side)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
