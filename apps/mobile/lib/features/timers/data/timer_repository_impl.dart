import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/device_timer.dart';
import '../domain/repositories/timer_repository.dart';

class TimerRepositoryImpl implements TimerRepository {
  const TimerRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<DeviceTimer>> getTimers(String deviceId) async {
    final json = await _api.get('/v1/devices/$deviceId/timers');
    return [for (final t in ApiClient.items(json)) _fromJson(t)]
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  }

  @override
  Future<DeviceTimer> create(String deviceId, TimerDraft draft) async => _fromJson(
        await _api.post(
          '/v1/devices/$deviceId/timers',
          body: {
            'time': '${Formatters.two(draft.hour)}:${Formatters.two(draft.minute)}',
            'days': draft.days,
            'dps': draft.dps,
          },
          idempotent: true,
        ),
      );

  @override
  Future<void> setEnabled(String timerId, {required bool enabled}) =>
      _api.patch('/v1/timers/$timerId', body: {'enabled': enabled});

  @override
  Future<void> delete(String timerId) => _api.delete('/v1/timers/$timerId');

  static DeviceTimer _fromJson(JsonMap t) {
    final [hour, minute] = (t['time'] as String).split(':').map(int.parse).toList();
    return DeviceTimer(
      id: t['id'] as String,
      deviceId: t['device_id'] as String,
      hour: hour,
      minute: minute,
      days: (t['days'] as List<Object?>? ?? const []).cast<num>().map((d) => d.toInt()).toList(),
      dps: Map<String, Object?>.of(t['dps'] as Map<String, dynamic>? ?? const {}),
      enabled: t['enabled'] as bool? ?? true,
    );
  }
}
