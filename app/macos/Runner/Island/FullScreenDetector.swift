import AppKit

/// Tells whether another app is covering the island's screen in full
/// screen (a video, a game, a presentation). Only window bounds and owners
/// are read, which needs no Screen Recording permission.
enum FullScreenDetector {
  static func isFullScreenAppActive(on screen: NSScreen?) -> Bool {
    guard let screen = screen,
          let front = NSWorkspace.shared.frontmostApplication,
          front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
          let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                   kCGNullWindowID) as? [[String: Any]]
    else { return false }

    let size = screen.frame.size
    return windows.contains { info in
      guard (info[kCGWindowOwnerPID as String] as? pid_t) == front.processIdentifier,
            (info[kCGWindowLayer as String] as? Int) == 0,
            let raw = info[kCGWindowBounds as String] as? [String: CGFloat],
            let width = raw["Width"], let height = raw["Height"]
      else { return false }
      return width >= size.width && height >= size.height
    }
  }
}
