import AppKit
import SwiftUI

/// Owns the island panel: places it over the notch, shows and hides it and
/// forwards new readings to the SwiftUI tree.
final class IslandWindowController {
  let state = IslandState()

  /// Called when the person asks to go back to the app.
  var onOpen: () -> Void = {}

  private lazy var panel: IslandPanel = {
    let panel = IslandPanel()
    let host = NSHostingView(rootView: IslandRootView(state: state, actions: makeActions()))
    host.autoresizingMask = [.width, .height]
    panel.contentView = host
    return panel
  }()

  private var screen: NSScreen?

  var isShown: Bool { state.isVisible }

  func show() {
    screen = NotchGeometry.preferredScreen()
    if let screen = screen { state.geometry = NotchGeometry(screen: screen) }
    state.isExpanded = false
    place(size: state.geometry.compactSize)
    panel.orderFrontRegardless()
    state.isVisible = true
  }

  func hide() {
    guard state.isVisible else { return }
    state.isVisible = false
    state.isExpanded = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
      guard let self = self, !self.state.isVisible else { return }
      self.panel.orderOut(nil)
    }
  }

  func update(_ payload: IslandPayload) {
    state.payload = payload
  }

  /// Puts the panel at the top centre of the screen, flush with its edge.
  private func place(size: CGSize) {
    guard let frame = (screen ?? NSScreen.main)?.frame else { return }
    let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height)
    panel.setFrame(NSRect(origin: origin, size: size), display: true)
  }

  private func makeActions() -> IslandActions {
    IslandActions(
      hoverChanged: { _ in },
      open: { [weak self] in self?.onOpen() },
      toggle: {}
    )
  }
}
