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

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    channel = FlutterMethodChannel(name: IslandChannel.name, binaryMessenger: messenger)
    self.window = window
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
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
