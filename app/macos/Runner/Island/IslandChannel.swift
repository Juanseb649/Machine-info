import Cocoa
import FlutterMacOS

/// Bridge between Dart (`MethodChannelIslandHost`) and the native island.
/// Dart decides when the island is visible; this side reports window
/// events and draws whatever it is sent.
final class IslandChannel {
  static let name = "machine_info/island"

  private let channel: FlutterMethodChannel
  private let island = IslandWindowController()
  private weak var window: NSWindow?
  private var observers: [NSObjectProtocol] = []

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    channel = FlutterMethodChannel(name: IslandChannel.name, binaryMessenger: messenger)
    self.window = window
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    island.onOpen = { [weak self] in self?.restoreWindow() }
    island.onDismiss = { [weak self] in self?.send("islandDismissed") }
    observeWindow(window)
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }

  private func observeWindow(_ window: NSWindow) {
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                        object: nil, queue: .main) { [weak self] _ in
      self?.island.screensChanged()
    })
    observers.append(center.addObserver(forName: NSWindow.didMiniaturizeNotification,
                                        object: window, queue: .main) { [weak self] _ in
      self?.send("windowMinimized")
    })
    // Hiding the app (Cmd+H) also takes the window off screen, so the island
    // stands in for it just like when it is minimized.
    observers.append(center.addObserver(forName: NSApplication.didHideNotification,
                                        object: nil, queue: .main) { [weak self] _ in
      self?.send("windowMinimized")
    })
    observers.append(center.addObserver(forName: NSApplication.didUnhideNotification,
                                        object: nil, queue: .main) { [weak self] _ in
      guard let window = self?.window, !window.isMiniaturized else { return }
      self?.send("windowRestored")
    })
    observers.append(center.addObserver(forName: NSWindow.didDeminiaturizeNotification,
                                        object: window, queue: .main) { [weak self] _ in
      self?.send("windowRestored")
    })
  }

  /// Brings the main window back from the Dock and focuses the app.
  func restoreWindow() {
    island.hide()
    send("islandTapped")
    NSApp.unhide(nil)
    if let window = window {
      if window.isMiniaturized { window.deminiaturize(nil) }
      window.makeKeyAndOrderFront(nil)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "show":
      island.show()
      result(nil)
    case "hide":
      island.hide()
      result(nil)
    case "update":
      island.update(IslandPayload(call.arguments))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Tells Dart about something that happened natively.
  func send(_ event: String) {
    channel.invokeMethod(event, arguments: nil)
  }
}
