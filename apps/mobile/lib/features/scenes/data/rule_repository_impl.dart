import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../domain/entities/rule.dart';
import '../domain/entities/rule_draft.dart';
import '../domain/repositories/rule_repository.dart';

class RuleRepositoryImpl implements RuleRepository {
  const RuleRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Rule>> getRules(String homeId) async {
    final json = await _api.get('/v1/homes/$homeId/rules');
    return [for (final r in ApiClient.items(json)) _fromJson(r, homeId)];
  }

  @override
  Future<Rule> create(String homeId, RuleDraft draft) async => _fromJson(
        await _api.post('/v1/homes/$homeId/rules', body: toJson(draft), idempotent: true),
        homeId,
      );

  @override
  Future<void> runScene(String ruleId) =>
      _api.post('/v1/rules/$ruleId/run', idempotent: true);

  @override
  Future<void> setEnabled(String ruleId, {required bool enabled}) =>
      _api.put('/v1/rules/$ruleId/enabled', body: {'enabled': enabled});

  /// Rule document as defined in docs/architecture/04-backend-services.md §9.1.
  static Map<String, Object?> toJson(RuleDraft draft) => {
        'kind': draft.kind.name,
        'name': draft.name.trim(),
        'icon': draft.icon,
        'color': draft.colorHex,
        'match': draft.match.name,
        'conditions': [
          for (final c in draft.conditions)
            switch (c) {
              ScheduleCondition(:final hour, :final minute, :final days) => <String, Object?>{
                  'type': 'schedule',
                  'spec': {
                    'type': 'weekly',
                    'time': '${Formatters.two(hour)}:${Formatters.two(minute)}',
                    'days': days,
                  },
                },
              DeviceStateCondition(:final deviceId, :final dp, :final value) => <String, Object?>{
                  'type': 'device_dp',
                  'device_id': deviceId,
                  'dp': dp,
                  'op': '==',
                  'value': value,
                },
            },
        ],
        'actions': [
          for (final a in draft.actions)
            switch (a) {
              DeviceAction(:final deviceId, :final dps) =>
                <String, Object?>{'type': 'device', 'device_id': deviceId, 'dps': dps},
              DelayAction(:final seconds) => <String, Object?>{'type': 'delay', 'seconds': seconds},
            },
        ],
      };

  static Rule _fromJson(JsonMap r, String homeId) => Rule(
        id: r['id'] as String,
        homeId: homeId,
        kind: r['kind'] == 'scene' ? RuleKind.scene : RuleKind.automation,
        name: r['name'] as String,
        enabled: r['enabled'] as bool? ?? true,
        icon: r['icon'] as String?,
        colorHex: r['color'] as String?,
        summary: r['summary'] as String?,
      );
}
