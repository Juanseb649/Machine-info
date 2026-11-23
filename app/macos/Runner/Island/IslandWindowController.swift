import AppKit
import SwiftUI

/// Owns the island panel: places it over the notch, shows and hides it and
/// forwards new readings to the SwiftUI tree.
final class IslandWindowController {
  let state = IslandState()

  /// Called when the person asks to go back to the app.
  var onOpen: () -> Void = {}

  /// Called when the person hides the island from its menu.
  var onDismiss: () -> Void = {}

  private lazy var panel: IslandPanel = {
    let panel = IslandPanel()
    let host = NSHostingView(rootView: IslandRootView(state: state, actions: makeActions()))
    host.autoresizingMask = [.width, .height]
    panel.contentView = host
    return panel
  }()

  private var screen: NSScreen?
  private var pendingHover: DispatchWorkItem?
  private var pendingShrink: DispatchWorkItem?

  /// Delay before opening on hover, so passing the pointer to the menu bar
  /// does not pop the island open.
  private let openDelay: TimeInterval = 0.12
  private let closeDelay: TimeInterval = 0.3

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

  /// Re-measures the notch and re-centres the panel, e.g. after a display
  /// is connected, disconnected or changes resolution.
  func screensChanged() {
    guard state.isVisible else { return }
    screen = NotchGeometry.preferredScreen()
    if let screen = screen { state.geometry = NotchGeometry(screen: screen) }
    place(size: state.isExpanded ? NotchGeometry.expandedSize : state.geometry.compactSize)
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

  func setExpanded(_ expanded: Bool) {
    guard state.isVisible, expanded != state.isExpanded else { return }
    pendingShrink?.cancel()
    if expanded {
      // Grow the window first so the spring has room to play.
      place(size: NotchGeometry.expandedSize)
      state.isExpanded = true
    } else {
      state.isExpanded = false
      let shrink = DispatchWorkItem { [weak self] in
        guard let self = self, !self.state.isExpanded else { return }
        self.place(size: self.state.geometry.compactSize)
      }
      pendingShrink = shrink
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: shrink)
    }
  }

  private func hoverChanged(_ inside: Bool) {
    pendingHover?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.setExpanded(inside) }
    pendingHover = work
    DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? openDelay : closeDelay), execute: work)
  }

  private func makeActions() -> IslandActions {
    IslandActions(
      hoverChanged: { [weak self] inside in self?.hoverChanged(inside) },
      open: { [weak self] in self?.onOpen() },
      toggle: { [weak self] in
        guard let self = self else { return }
        self.setExpanded(!self.state.isExpanded)
      },
      dismiss: { [weak self] in
        self?.hide()
        self?.onDismiss()
      },
      quit: { NSApp.terminate(nil) }
    )
  }
}
