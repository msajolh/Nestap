import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestap/features/devices/domain/entities/device.dart';
import 'package:nestap/features/devices/presentation/widgets/device_tile.dart';

Device _device({bool online = true, bool on = true}) => Device(
      id: 'd1',
      homeId: 'h1',
      name: 'TV Socket',
      category: DeviceCategory.socket,
      productId: 'p',
      online: online,
      state: {'switch_1': on, 'cur_power': on ? 86.4 : 0.0},
      version: 1,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 220, height: 156, child: child))),
    );

void main() {
  testWidgets('shows name, room and live power', (tester) async {
    await tester.pumpWidget(
      _host(DeviceTile(device: _device(), roomName: 'Living Room', onTap: () {})),
    );
    expect(find.text('TV Socket'), findsOneWidget);
    expect(find.text('Living Room · 86 W'), findsOneWidget);
  });

  testWidgets('power button sends the opposite state', (tester) async {
    bool? requested;
    await tester.pumpWidget(
      _host(DeviceTile(device: _device(), onTap: () {}, onTogglePower: (on) => requested = on)),
    );
    await tester.tap(find.byTooltip('Turn off'));
    expect(requested, isFalse);
  });

  testWidgets('offline devices hide the power button', (tester) async {
    await tester.pumpWidget(
      _host(DeviceTile(device: _device(online: false), onTap: () {}, onTogglePower: (_) {})),
    );
    expect(find.byTooltip('Turn on'), findsNothing);
    expect(find.text('Offline'), findsOneWidget);
  });
}
