import 'package:material_ui/material_ui.dart';

import '../../domain/entities/device.dart';

extension DeviceVisuals on Device {
  IconData get icon => switch (category) {
        DeviceCategory.switchPanel => Icons.toggle_on_outlined,
        DeviceCategory.socket => Icons.power_outlined,
        DeviceCategory.light => Icons.lightbulb_outline_rounded,
        DeviceCategory.curtain => Icons.curtains_outlined,
        DeviceCategory.sensor => Icons.sensors_rounded,
        DeviceCategory.gateway => Icons.router_outlined,
        DeviceCategory.unknown => Icons.devices_other_rounded,
      };

  /// One-line status under the device name.
  String get statusLine {
    if (!online) return 'Offline';
    final power = powerW;
    if (power != null && isOn) return '${power.toStringAsFixed(power < 10 ? 1 : 0)} W';
    if (category == DeviceCategory.curtain) {
      final p = position;
      return p == null ? 'Ready' : (p == 0 ? 'Closed' : (p == 100 ? 'Open' : '$p% open'));
    }
    final gangs = switchCodes;
    if (gangs.length > 1) {
      final on = gangs.where((c) => state[c] == true).length;
      return on == 0 ? 'All off' : '$on of ${gangs.length} on';
    }
    return isOn ? 'On' : 'Off';
  }
}

/// "Switch 1" … labels for gangs; product panels can override these later.
String gangLabel(String code) => 'Switch ${code.replaceFirst('switch_', '')}';
