import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machine_info/src/domain/island_host.dart';
import 'package:machine_info/src/infrastructure/method_channel_island_host.dart';
import 'package:machine_info/src/infrastructure/unsupported_island_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelIslandHost.channelName);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('forwards calls and payloads to the native side', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isSupported' ? true : null;
    });
    final host = MethodChannelIslandHost();
    expect(await host.isSupported(), isTrue);
    await host.show();
    await host.update({'title': 'Machine Info'});
    await host.hide();
    expect(calls.map((c) => c.method), ['isSupported', 'show', 'update', 'hide']);
    expect(calls[2].arguments, {'title': 'Machine Info'});
  });

  test('reports unsupported when the runner has no island', () async {
    final host = MethodChannelIslandHost();
    expect(await host.isSupported(), isFalse);
    await host.show();
  });

  test('turns native callbacks into events', () async {
    final host = MethodChannelIslandHost();
    final events = <IslandEvent>[];
    host.events.listen(events.add);
    for (final method in ['windowMinimized', 'islandTapped', 'unknown']) {
      await messenger.handlePlatformMessage(
        MethodChannelIslandHost.channelName,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        (_) {},
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(events, [IslandEvent.windowMinimized, IslandEvent.islandTapped]);
  });

  test('the fallback host is inert', () async {
    const host = UnsupportedIslandHost();
    expect(await host.isSupported(), isFalse);
    expect(await host.events.isEmpty, isTrue);
  });
}
