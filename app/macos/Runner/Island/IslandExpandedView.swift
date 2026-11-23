import SwiftUI

/// Open island: a header beside the camera, one tile per reading and a
/// footer with the uptime and a button back to the app.
struct IslandExpandedView: View {
  let payload: IslandPayload
  let geometry: NotchGeometry
  let onOpen: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      header
      if payload.readings.isEmpty {
        Text("Leyendo el hardware…")
          .font(.system(size: 12))
          .foregroundColor(IslandPalette.secondaryText)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        HStack(spacing: 10) {
          ForEach(payload.readings) { reading in
            ReadingTile(reading: reading)
          }
        }
      }
      footer
    }
    .padding(.horizontal, 22)
    .padding(.bottom, 14)
  }

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 1) {
        Text(payload.title)
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(IslandPalette.primaryText)
        if !payload.hostname.isEmpty {
          Text(payload.hostname)
            .font(.system(size: 10))
            .foregroundColor(IslandPalette.secondaryText)
            .lineLimit(1)
        }
      }
      Spacer(minLength: geometry.notchWidth + 8)
      LiveBadge(level: payload.level, time: payload.updatedAt)
    }
    .frame(height: geometry.height)
  }

  private var footer: some View {
    HStack {
      if !payload.uptime.isEmpty {
        Label("Encendido \(payload.uptime)", systemImage: "clock")
          .font(.system(size: 10))
          .foregroundColor(IslandPalette.secondaryText)
      }
      Spacer()
      Button(action: onOpen) {
        Label("Abrir Machine Info", systemImage: "arrow.up.forward.app")
          .font(.system(size: 11, weight: .semibold))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Capsule().fill(Color.white.opacity(0.14)))
          .foregroundColor(IslandPalette.primaryText)
      }
      .buttonStyle(.plain)
    }
  }
}

/// One reading inside the open island.
private struct ReadingTile: View {
  let reading: IslandReading

  var body: some View {
    VStack(spacing: 5) {
      MeterRing(ratio: reading.ratio, level: reading.level, symbol: reading.symbol,
                lineWidth: 4, iconScale: 0.36)
        .frame(width: 44, height: 44)
      Text(reading.value)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundColor(IslandPalette.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(reading.label.uppercased())
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(IslandPalette.accent(reading.level))
      Text(reading.detail)
        .font(.system(size: 9))
        .foregroundColor(IslandPalette.secondaryText)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(IslandPalette.hairline))
  }
}

/// Pulsing dot that tells the readings are live, tinted by the worst level.
private struct LiveBadge: View {
  let level: IslandLevel
  let time: String
  @State private var pulse = false

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(IslandPalette.accent(level))
        .frame(width: 6, height: 6)
        .opacity(pulse ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
      Text(time.isEmpty ? "En vivo" : time)
        .font(.system(size: 10, weight: .medium))
        .monospacedDigit()
        .foregroundColor(IslandPalette.secondaryText)
    }
  }
}
