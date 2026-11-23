import AppKit

/// Borderless, non-activating panel that floats above the menu bar on every
/// space. It never becomes key, so hovering or clicking it does not steal
/// focus from whatever the person is doing.
final class IslandPanel: NSPanel {
  init() {
    super.init(contentRect: .zero,
               styleMask: [.borderless, .nonactivatingPanel],
               backing: .buffered,
               defer: true)
    isFloatingPanel = true
    level = .statusBar
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false
    hidesOnDeactivate = false
    isMovable = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
