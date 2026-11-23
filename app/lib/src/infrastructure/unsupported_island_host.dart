import 'dart:io';

import '../domain/island_host.dart';
import 'method_channel_island_host.dart';

/// Island for platforms whose runner cannot draw a floating notch window
/// (Windows and Linux for now). The app keeps working; the settings explain
/// that the island is only available on macOS.
class UnsupportedIslandHost implements IslandHost {
  const UnsupportedIslandHost();

  @override
  Stream<IslandEvent> get events => const Stream.empty();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> show() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> update(Map<String, Object?> payload) async {}
}

/// Picks the island implementation for the running platform.
IslandHost createIslandHost() =>
    Platform.isMacOS ? MethodChannelIslandHost() : const UnsupportedIslandHost();
