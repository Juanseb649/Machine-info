/// Things that happen on the native side of the Dynamic Island.
enum IslandEvent {
  /// The main window was minimized or the app was hidden.
  windowMinimized,

  /// The main window came back on screen.
  windowRestored,

  /// The person clicked the island to bring the app back.
  islandTapped,

  /// The person dismissed the island from its menu until the next minimize.
  islandDismissed,
}

/// Port for the floating, notch-like window that shows live readings while
/// the main window is minimized. Platforms that cannot draw it report
/// [isSupported] as false and ignore the other calls.
abstract interface class IslandHost {
  Future<bool> isSupported();

  Future<void> show();

  Future<void> hide();

  /// Sends the latest readings, already formatted by the application layer.
  Future<void> update(Map<String, Object?> payload);

  Stream<IslandEvent> get events;
}
