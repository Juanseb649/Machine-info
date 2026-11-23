import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/island_host.dart';

/// Talks to the native Dynamic Island over a method channel. The macOS
/// runner implements the other end in `Runner/Island/IslandChannel.swift`.
class MethodChannelIslandHost implements IslandHost {
  MethodChannelIslandHost({MethodChannel channel = const MethodChannel(channelName)}) : _channel = channel {
    _channel.setMethodCallHandler(_handle);
  }

  static const channelName = 'machine_info/island';

  final MethodChannel _channel;
  final _events = StreamController<IslandEvent>.broadcast();

  @override
  Stream<IslandEvent> get events => _events.stream;

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> show() => _invoke('show');

  @override
  Future<void> hide() => _invoke('hide');

  @override
  Future<void> update(Map<String, Object?> payload) => _invoke('update', payload);

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // The runner of this platform has no island; nothing to do.
    }
  }

  Future<void> _handle(MethodCall call) async {
    final event = switch (call.method) {
      'windowMinimized' => IslandEvent.windowMinimized,
      'windowRestored' => IslandEvent.windowRestored,
      'islandTapped' => IslandEvent.islandTapped,
      'islandDismissed' => IslandEvent.islandDismissed,
      _ => null,
    };
    if (event != null) _events.add(event);
  }
}
