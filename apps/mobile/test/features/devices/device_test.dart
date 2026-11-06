import 'package:flutter_test/flutter_test.dart';
import 'package:nestap/features/devices/domain/entities/device.dart';

Device _switch(Map<String, Object?> state) => Device(
      id: 'd1',
      homeId: 'h1',
      name: 'Switch',
      category: DeviceCategory.switchPanel,
      productId: 'p',
      online: true,
      state: state,
      version: 1,
    );

void main() {
  test('switchCodes are in gang order, not string order', () {
    final device = _switch({'switch_10': false, 'switch_2': true, 'switch_1': false});
    expect(device.switchCodes, ['switch_1', 'switch_2', 'switch_10']);
  });

  test('isOn is true when any gang is on', () {
    expect(_switch({'switch_1': false, 'switch_2': true}).isOn, isTrue);
    expect(_switch({'switch_1': false, 'switch_2': false}).isOn, isFalse);
  });

  test('allChannels targets every gang', () {
    final dps = _switch({'switch_1': true, 'switch_2': false, 'cur_power': 5}).allChannels(false);
    expect(dps, {'switch_1': false, 'switch_2': false});
  });

  test('applyChanges merges state and keeps the newer version', () {
    final updated = _switch({'switch_1': false, 'switch_2': true})
        .applyChanges({'switch_1': true}, version: 7);
    expect(updated.state, {'switch_1': true, 'switch_2': true});
    expect(updated.version, 7);
  });

  test('category codes match sub-categories', () {
    expect(DeviceCategory.fromCode('sensor.pir'), DeviceCategory.sensor);
    expect(DeviceCategory.fromCode('switch'), DeviceCategory.switchPanel);
    expect(DeviceCategory.fromCode('kettle'), DeviceCategory.unknown);
  });
}
