import 'dart:async';
import 'dart:convert';

/// In-memory stand-in for the Nestap cloud, used when no API URL is configured.
///
/// It speaks the same JSON as the real API (`docs/architecture/04-backend-services.md`),
/// so the real data layer (DTO parsing, error mapping, realtime handling) runs
/// unchanged against it. The seed data mirrors a typical Nalite D6 install.
class DemoBackend {
  DemoBackend() {
    _seed();
  }

  final _events = StreamController<Map<String, Object?>>.broadcast();
  final List<Map<String, Object?>> _homes = [];
  final List<Map<String, Object?>> _rooms = [];
  final List<Map<String, Object?>> _devices = [];
  final List<Map<String, Object?>> _rules = [];
  final List<Map<String, Object?>> _timers = [];
  final List<Map<String, Object?>> _messages = [];
  int _sequence = 100;

  Map<String, Object?> get user => {
        'id': 'u_demo',
        'display_name': 'Demo User',
        'email': 'demo@nestap.net',
        'phone': null,
        'avatar_url': null,
      };

  /// Realtime messages, in the realtime gateway's wire format.
  Stream<Map<String, Object?>> get events => _events.stream;

  List<Map<String, Object?>> homes() => _copy(_homes);

  List<Map<String, Object?>> rooms(String homeId) =>
      _copy(_rooms.where((r) => r['home_id'] == homeId).toList());

  List<Map<String, Object?>> devices(String homeId) =>
      _copy(_devices.where((d) => d['home_id'] == homeId).toList());

  List<Map<String, Object?>> rules(String homeId) =>
      _copy(_rules.where((r) => r['home_id'] == homeId).toList());

  Map<String, Object?>? device(String id) {
    for (final d in _devices) {
      if (d['id'] == id) return d;
    }
    return null;
  }

  /// Applies a command the way a real device would, then reports the new
  /// state over realtime a moment later.
  void applyDps(String deviceId, Map<String, Object?> dps) {
    final device = this.device(deviceId);
    if (device == null) return;
    final state = (device['state']! as Map<String, Object?>)..addAll(dps);
    final changed = Map<String, Object?>.of(dps);

    // Simulated metering for sockets and the water heater.
    final ratedPower = device['rated_power_w'] as double?;
    if (ratedPower != null && dps.containsKey('switch_1')) {
      final on = dps['switch_1'] == true;
      final power = on ? ratedPower : 0.0;
      final current = on ? (ratedPower / 230 * 1000).roundToDouble() : 0.0;
      state['cur_power'] = power;
      state['cur_current'] = current;
      changed['cur_power'] = power;
      changed['cur_current'] = current;
    }

    // Curtains move to the end stop.
    final control = dps['control'];
    if (control == 'open' || control == 'close') {
      final position = control == 'open' ? 100 : 0;
      state['percent_control'] = position;
      changed['percent_control'] = position;
    }

    final version = (device['version']! as int) + 1;
    device['version'] = version;
    Timer(const Duration(milliseconds: 180), () {
      _events.add({
        'type': 'state',
        'device_id': deviceId,
        'version': version,
        'changed': changed,
      });
    });
  }

  void runRule(String ruleId) {
    final rule = _rules.firstWhere((r) => r['id'] == ruleId);
    for (final action in (rule['actions']! as List<Object?>).cast<Map<String, Object?>>()) {
      // Delays are skipped in the demo; device actions run at once.
      final deviceId = action['device_id'];
      final dps = action['dps'];
      if (deviceId is String && dps is Map<String, Object?>) applyDps(deviceId, dps);
    }
    _message(category: 'home', title: '${rule['name']} ran', body: 'Scene finished.');
  }

  Map<String, Object?> createRule(String homeId, Map<String, Object?> body) {
    final kind = body['kind'] == 'automation' ? 'automation' : 'scene';
    final rule = {
      'id': 'rule_${_sequence++}',
      'home_id': homeId,
      'kind': kind,
      'name': body['name'],
      'icon': body['icon'],
      'color': body['color'],
      'enabled': true,
      'summary': kind == 'automation' ? _summarise(body['conditions']) : null,
      'actions': body['actions'] ?? <Object?>[],
    };
    _rules.add(rule);
    return _copy([rule]).single;
  }

  String _summarise(Object? conditions) {
    final list = conditions is List ? conditions.cast<Map<String, Object?>>() : const <Map<String, Object?>>[];
    if (list.isEmpty) return 'No conditions';
    final first = list.first;
    if (first['type'] == 'schedule') {
      final spec = first['spec'] as Map<String, Object?>? ?? const {};
      return 'Schedule · ${spec['time']}';
    }
    final device = this.device('${first['device_id']}');
    return 'When ${device?['name'] ?? 'a device'} changes';
  }

  // ---------------------------------------------------------------- devices

  Map<String, Object?> patchDevice(String id, Map<String, Object?> body) {
    final device = this.device(id);
    if (device == null) throw StateError('Unknown device $id');
    if (body.containsKey('name')) device['name'] = body['name'];
    if (body.containsKey('room_id')) device['room_id'] = body['room_id'];
    return _copy([device]).single;
  }

  void removeDevice(String id) {
    _devices.removeWhere((d) => d['id'] == id);
    _timers.removeWhere((t) => t['device_id'] == id);
    _events.add({'type': 'device_removed', 'device_id': id});
  }

  /// Synthetic but stable energy history, shaped like a real household day.
  Map<String, Object?> energy(String deviceId, String range) {
    final device = this.device(deviceId);
    final rated = (device?['rated_power_w'] as double?) ?? 60;
    final seed = deviceId.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFF);
    double factor(int i) => (((seed + i * 7919) % 100) / 100) * 0.6 + 0.2;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final points = <Map<String, Object?>>[];
    switch (range) {
      case 'day':
        for (var h = 0; h < 24; h++) {
          final daytime = h >= 7 && h <= 23 ? 1.0 : 0.25;
          points.add({
            'start': today.add(Duration(hours: h)).toIso8601String(),
            'kwh': h > now.hour ? 0.0 : _round(rated / 1000 * factor(h) * daytime),
          });
        }
      case 'month':
        for (var d = 29; d >= 0; d--) {
          points.add({
            'start': today.subtract(Duration(days: d)).toIso8601String(),
            'kwh': _round(rated / 1000 * 9 * factor(d)),
          });
        }
      default:
        for (var d = 6; d >= 0; d--) {
          points.add({
            'start': today.subtract(Duration(days: d)).toIso8601String(),
            'kwh': _round(rated / 1000 * 9 * factor(d)),
          });
        }
    }
    final total = points.fold<double>(0, (sum, p) => sum + (p['kwh']! as double));
    return {'range': range, 'total_kwh': _round(total), 'points': points};
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  // ---------------------------------------------------------------- timers

  List<Map<String, Object?>> timers(String deviceId) =>
      _copy(_timers.where((t) => t['device_id'] == deviceId).toList());

  Map<String, Object?> addTimer(String deviceId, Map<String, Object?> body) {
    final timer = {
      'id': 'tm_${_sequence++}',
      'device_id': deviceId,
      'time': body['time'],
      'days': body['days'] ?? <Object?>[],
      'dps': body['dps'],
      'enabled': true,
    };
    _timers.add(timer);
    return _copy([timer]).single;
  }

  void patchTimer(String id, Map<String, Object?> body) {
    final timer = _timers.firstWhere((t) => t['id'] == id);
    if (body.containsKey('enabled')) timer['enabled'] = body['enabled'];
  }

  void deleteTimer(String id) => _timers.removeWhere((t) => t['id'] == id);

  // ---------------------------------------------------------------- messages

  List<Map<String, Object?>> messages() => _copy(_messages.reversed.toList());

  void markRead(List<String>? ids) {
    for (final m in _messages) {
      if (ids == null || ids.contains(m['id'])) m['read'] = true;
    }
  }

  void _message({
    required String category,
    required String title,
    required String body,
    DateTime? at,
    bool read = false,
  }) {
    _messages.add({
      'id': 'msg_${_sequence++}',
      'category': category,
      'title': title,
      'body': body,
      'created_at': (at ?? DateTime.now()).toIso8601String(),
      'read': read,
    });
  }

  // ---------------------------------------------------------------- home

  Map<String, Object?> addRoom(String homeId, String name) {
    final room = {'id': 'r_${_sequence++}', 'home_id': homeId, 'name': name};
    _rooms.add(room);
    return _copy([room]).single;
  }

  void renameRoom(String roomId, String name) =>
      _rooms.firstWhere((r) => r['id'] == roomId)['name'] = name;

  void deleteRoom(String roomId) {
    _rooms.removeWhere((r) => r['id'] == roomId);
    for (final d in _devices) {
      if (d['room_id'] == roomId) d['room_id'] = null;
    }
  }

  List<Map<String, Object?>> members(String homeId) => [
        {'user_id': 'u_demo', 'display_name': 'Demo User', 'contact': 'demo@nestap.net', 'role': 'owner'},
        {'user_id': 'u_rahim', 'display_name': 'Rahim Ahmed', 'contact': '+8801711000000', 'role': 'member'},
      ];

  Map<String, Object?> createInvitation(String homeId, String role) => {
        'code': 'K7Q2-${(_sequence++).toString().padLeft(4, '0')}',
        'role': role,
        'expires_at': DateTime.now().add(const Duration(hours: 72)).toIso8601String(),
      };

  void setRuleEnabled(String ruleId, bool enabled) {
    _rules.firstWhere((r) => r['id'] == ruleId)['enabled'] = enabled;
  }

  /// Simulates a Tuya device that just finished pairing and was imported.
  Map<String, Object?> importDevice({required String homeId, String? roomId}) {
    final id = 'nd_demo_${_sequence++}';
    final device = _device(
      id: id,
      homeId: homeId,
      roomId: roomId,
      name: 'Smart Plug',
      category: 'socket',
      state: {'switch_1': false, 'cur_power': 0.0, 'cur_voltage': 230.1, 'cur_current': 0.0},
      ratedPower: 60,
    );
    _devices.add(device);
    _events.add({'type': 'device_added', 'device_id': id});
    return _copy([device]).single;
  }

  void _seed() {
    const home = 'h_demo';
    _homes.add({'id': home, 'name': 'My Home', 'timezone': 'Asia/Dhaka'});
    _rooms.addAll([
      {'id': 'r_living', 'home_id': home, 'name': 'Living Room'},
      {'id': 'r_bed', 'home_id': home, 'name': 'Bedroom'},
      {'id': 'r_kitchen', 'home_id': home, 'name': 'Kitchen'},
      {'id': 'r_bath', 'home_id': home, 'name': 'Bathroom'},
    ]);
    _devices.addAll([
      _device(
        id: 'nd_living_lights',
        homeId: home,
        roomId: 'r_living',
        name: 'Living Room Lights',
        category: 'switch',
        productId: 'nalite_d6_3g',
        state: {'switch_1': true, 'switch_2': false, 'switch_3': true},
      ),
      _device(
        id: 'nd_tv_socket',
        homeId: home,
        roomId: 'r_living',
        name: 'TV Socket',
        category: 'socket',
        state: {'switch_1': true, 'cur_power': 86.4, 'cur_voltage': 229.8, 'cur_current': 376.0},
        ratedPower: 86.4,
      ),
      _device(
        id: 'nd_curtain',
        homeId: home,
        roomId: 'r_living',
        name: 'Window Curtain',
        category: 'curtain',
        state: {'control': 'stop', 'percent_control': 60},
      ),
      _device(
        id: 'nd_bed_switch',
        homeId: home,
        roomId: 'r_bed',
        name: 'Bedroom Switch',
        category: 'switch',
        productId: 'nalite_d6_2g',
        state: {'switch_1': false, 'switch_2': false},
      ),
      _device(
        id: 'nd_kitchen_light',
        homeId: home,
        roomId: 'r_kitchen',
        name: 'Kitchen Light',
        category: 'light',
        state: {'switch_led': false, 'bright_value': 600},
      ),
      _device(
        id: 'nd_heater',
        homeId: home,
        roomId: 'r_bath',
        name: 'Water Heater',
        category: 'switch',
        productId: 'nalite_d6_20a',
        state: {'switch_1': false, 'cur_power': 0.0, 'cur_voltage': 230.4, 'cur_current': 0.0},
        ratedPower: 1980,
      ),
      _device(
        id: 'nd_garage',
        homeId: home,
        roomId: null,
        name: 'Garage Switch',
        category: 'switch',
        online: false,
        state: {'switch_1': false},
      ),
    ]);
    _rules.addAll([
      {
        'id': 'rule_morning',
        'home_id': home,
        'kind': 'scene',
        'name': 'Good Morning',
        'icon': 'sunny',
        'color': '#00D3F3',
        'enabled': true,
        'actions': [
          {'device_id': 'nd_curtain', 'dps': {'control': 'open'}},
          {'device_id': 'nd_kitchen_light', 'dps': {'switch_led': true}},
          {'device_id': 'nd_heater', 'dps': {'switch_1': true}},
        ],
      },
      {
        'id': 'rule_leave',
        'home_id': home,
        'kind': 'scene',
        'name': 'Leave Home',
        'icon': 'logout',
        'color': '#4A5565',
        'enabled': true,
        'actions': [
          {'device_id': 'nd_living_lights', 'dps': {'switch_1': false, 'switch_2': false, 'switch_3': false}},
          {'device_id': 'nd_bed_switch', 'dps': {'switch_1': false, 'switch_2': false}},
          {'device_id': 'nd_kitchen_light', 'dps': {'switch_led': false}},
          {'device_id': 'nd_tv_socket', 'dps': {'switch_1': false}},
          {'device_id': 'nd_heater', 'dps': {'switch_1': false}},
        ],
      },
      {
        'id': 'rule_movie',
        'home_id': home,
        'kind': 'scene',
        'name': 'Movie Time',
        'icon': 'movie',
        'color': '#96F7E4',
        'enabled': true,
        'actions': [
          {'device_id': 'nd_curtain', 'dps': {'control': 'close'}},
          {'device_id': 'nd_living_lights', 'dps': {'switch_1': false, 'switch_2': true, 'switch_3': false}},
          {'device_id': 'nd_tv_socket', 'dps': {'switch_1': true}},
        ],
      },
      {
        'id': 'rule_sunset',
        'home_id': home,
        'kind': 'automation',
        'name': 'Lights on at sunset',
        'summary': 'Every day · Sunset − 15 min',
        'enabled': true,
        'actions': <Object?>[],
      },
      {
        'id': 'rule_heater_off',
        'home_id': home,
        'kind': 'automation',
        'name': 'Heater off at 11 PM',
        'summary': 'Every day · 23:00',
        'enabled': false,
        'actions': <Object?>[],
      },
    ]);
    _timers.addAll([
      {
        'id': 'tm_1',
        'device_id': 'nd_living_lights',
        'time': '18:30',
        'days': [1, 2, 3, 4, 5, 6, 7],
        'dps': {'switch_1': true, 'switch_2': true, 'switch_3': true},
        'enabled': true,
      },
      {
        'id': 'tm_2',
        'device_id': 'nd_heater',
        'time': '06:30',
        'days': [1, 2, 3, 4, 5],
        'dps': {'switch_1': true},
        'enabled': true,
      },
    ]);
    final now = DateTime.now();
    _message(
      category: 'home',
      title: 'Good Morning ran',
      body: 'Curtain opened, kitchen light and water heater on.',
      at: now.subtract(const Duration(days: 1, hours: 2)),
      read: true,
    );
    _message(
      category: 'device',
      title: 'Garage Switch went offline',
      body: 'Check its power and Wi-Fi.',
      at: now.subtract(const Duration(hours: 2)),
    );
    _message(
      category: 'alarm',
      title: 'Water Heater overload',
      body: 'Current exceeded 16 A, so the switch turned itself off.',
      at: now.subtract(const Duration(minutes: 25)),
    );
  }

  Map<String, Object?> _device({
    required String id,
    required String homeId,
    required String? roomId,
    required String name,
    required String category,
    required Map<String, Object?> state,
    String productId = 'demo_product',
    bool online = true,
    double? ratedPower,
  }) =>
      {
        'id': id,
        'home_id': homeId,
        'room_id': roomId,
        'name': name,
        'category': category,
        'product_id': productId,
        'transport': 'tuya_cloud',
        'online': online,
        'version': 1,
        'state': state,
        'rated_power_w': ratedPower,
      };

  /// Deep copy through JSON, exactly like a network round trip.
  static List<Map<String, Object?>> _copy(List<Map<String, Object?>> value) =>
      (jsonDecode(jsonEncode(value)) as List<Object?>).cast<Map<String, Object?>>();
}
