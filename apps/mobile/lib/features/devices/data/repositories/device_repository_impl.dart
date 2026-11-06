import '../../../../core/network/api_client.dart';
import '../../domain/entities/device.dart';
import '../../domain/repositories/device_repository.dart';
import '../models/device_dto.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  const DeviceRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Device>> getHomeDevices(String homeId) async {
    final json = await _api.get('/v1/homes/$homeId/devices');
    return [for (final item in ApiClient.items(json)) DeviceDto(item).toDomain()];
  }

  @override
  Future<void> sendCommand(String deviceId, Map<String, Object?> dps) =>
      _api.post('/v1/devices/$deviceId/commands', body: {'dps': dps}, idempotent: true);

  @override
  Future<void> rename(String deviceId, String name) =>
      _api.patch('/v1/devices/$deviceId', body: {'name': name});

  @override
  Future<void> moveToRoom(String deviceId, String? roomId) =>
      _api.patch('/v1/devices/$deviceId', body: {'room_id': roomId});

  @override
  Future<void> remove(String deviceId) => _api.delete('/v1/devices/$deviceId');
}
