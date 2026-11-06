import '../../../../core/error/failures.dart';
import '../entities/device.dart';
import '../repositories/device_repository.dart';

class GetHomeDevices {
  const GetHomeDevices(this._repository);

  final DeviceRepository _repository;

  /// Sorted so the dashboard is stable: online first, then by name.
  Future<List<Device>> call(String homeId) async {
    final devices = await _repository.getHomeDevices(homeId);
    return [...devices]
      ..sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }
}

class SendDeviceCommand {
  const SendDeviceCommand(this._repository);

  final DeviceRepository _repository;

  Future<void> call(Device device, Map<String, Object?> dps) async {
    if (dps.isEmpty) return;
    if (!device.online) throw const DeviceOfflineFailure();
    await _repository.sendCommand(device.id, dps);
  }
}
