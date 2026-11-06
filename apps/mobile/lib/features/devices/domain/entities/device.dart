import 'package:equatable/equatable.dart';

/// Device categories from the catalog (`catalog.categories.code`).
enum DeviceCategory {
  switchPanel('switch'),
  socket('socket'),
  light('light'),
  curtain('curtain'),
  sensor('sensor'),
  gateway('gateway'),
  unknown('unknown');

  const DeviceCategory(this.code);

  final String code;

  /// Matches sub-categories too: `sensor.pir` → [sensor].
  static DeviceCategory fromCode(String code) => values.firstWhere(
        (c) => c.code == code || code.startsWith('${c.code}.'),
        orElse: () => unknown,
      );
}

/// A device and its current state (the shadow's `reported` side).
///
/// [state] is keyed by DP code with scale already applied, e.g.
/// `{'switch_1': true, 'cur_power': 86.4}` — the same for Tuya-backed and
/// Nestap-firmware devices.
class Device extends Equatable {
  const Device({
    required this.id,
    required this.homeId,
    required this.name,
    required this.category,
    required this.productId,
    required this.online,
    required this.state,
    required this.version,
    this.roomId,
    this.transport = 'nestap_mqtt',
  });

  static final _gang = RegExp(r'^switch_(\d+)$');

  final String id;
  final String homeId;
  final String? roomId;
  final String name;
  final DeviceCategory category;
  final String productId;
  final bool online;
  final Map<String, Object?> state;

  /// Shadow version; realtime updates older than this are ignored.
  final int version;

  /// `tuya_cloud`, `nestap_mqtt`, `gateway_zigbee`, `gateway_matter`.
  final String transport;

  /// `switch_1`, `switch_2`, … in gang order.
  List<String> get switchCodes {
    final codes = state.keys.where(_gang.hasMatch).toList()
      ..sort((a, b) => _gangNumber(a).compareTo(_gangNumber(b)));
    return codes;
  }

  /// The DP that turns the whole device on or off, if it has one.
  String? get powerCode => state.containsKey('switch_led')
      ? 'switch_led'
      : (state.containsKey('switch_1') ? 'switch_1' : null);

  bool get isOn =>
      state['switch_led'] == true || switchCodes.any((c) => state[c] == true);

  bool get hasMetering => state.containsKey('cur_power');

  double? get powerW => (state['cur_power'] as num?)?.toDouble();

  double? get voltageV => (state['cur_voltage'] as num?)?.toDouble();

  double? get currentMa => (state['cur_current'] as num?)?.toDouble();

  /// Brightness 10–1000 (Tuya scale) as 0.0–1.0.
  double? get brightness {
    final value = state['bright_value'] as num?;
    return value == null ? null : ((value - 10) / 990).clamp(0.0, 1.0).toDouble();
  }

  /// Curtain position 0 (closed) – 100 (open).
  int? get position => (state['percent_control'] as num?)?.toInt();

  /// Commands that would turn every channel on or off together.
  Map<String, Object?> allChannels(bool on) => {
        if (state.containsKey('switch_led')) 'switch_led': on,
        for (final code in switchCodes) code: on,
      };

  Device applyChanges(Map<String, Object?> changed, {int? version}) => copyWith(
        state: {...state, ...changed},
        version: version,
      );

  Device copyWith({
    String? name,
    String? roomId,
    bool? online,
    Map<String, Object?>? state,
    int? version,
  }) =>
      Device(
        id: id,
        homeId: homeId,
        roomId: roomId ?? this.roomId,
        name: name ?? this.name,
        category: category,
        productId: productId,
        online: online ?? this.online,
        state: state ?? this.state,
        version: version ?? this.version,
        transport: transport,
      );

  static int _gangNumber(String code) =>
      int.parse(_gang.firstMatch(code)!.group(1)!);

  @override
  List<Object?> get props =>
      [id, homeId, roomId, name, category, productId, online, state, version, transport];
}
