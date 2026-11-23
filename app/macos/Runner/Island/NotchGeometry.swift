import AppKit

/// Size and position of the camera housing on a display, or of a virtual
/// notch on displays without one, so the island hugs the top edge exactly.
struct NotchGeometry: Equatable {
  /// Width of the physical notch (or the virtual one).
  var notchWidth: CGFloat
  /// Height of the notch, equal to the menu bar on notched displays.
  var height: CGFloat
  /// Whether the display really has a camera housing.
  var hasNotch: Bool

  static let fallback = NotchGeometry(notchWidth: 180, height: 32, hasNotch: false)

  /// Space beside the notch used by the collapsed readings.
  static let wingWidth: CGFloat = 78
  static let expandedSize = CGSize(width: 460, height: 210)

  var compactSize: CGSize {
    CGSize(width: notchWidth + NotchGeometry.wingWidth * 2, height: height)
  }

  init(notchWidth: CGFloat, height: CGFloat, hasNotch: Bool) {
    self.notchWidth = notchWidth
    self.height = height
    self.hasNotch = hasNotch
  }

  init(screen: NSScreen) {
    let menuBar = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
    if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0,
       let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
      let width = screen.frame.width - left.width - right.width
      self.init(notchWidth: max(width, 120), height: screen.safeAreaInsets.top, hasNotch: true)
    } else {
      self.init(notchWidth: NotchGeometry.fallback.notchWidth, height: min(menuBar, 32), hasNotch: false)
    }
  }

  /// The screen that should host the island: the built-in one with a notch
  /// when present, otherwise the main display.
  static func preferredScreen() -> NSScreen? {
    if #available(macOS 12.0, *),
       let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
      return notched
    }
    return NSScreen.main ?? NSScreen.screens.first
  }
}
