import Combine
import Foundation

/// Shared, observable state between the panel controller and the SwiftUI
/// views. Only touched on the main thread.
final class IslandState: ObservableObject {
  @Published var payload = IslandPayload.empty
  @Published var isExpanded = false
  @Published var isVisible = false
  @Published var geometry = NotchGeometry.fallback

  /// True once Dart has sent at least one reading.
  var hasData: Bool { !payload.readings.isEmpty }
}
