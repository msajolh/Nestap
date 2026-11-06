import '../../../core/network/api_client.dart';
import '../domain/entities/rule.dart';
import '../domain/repositories/rule_repository.dart';

class RuleRepositoryImpl implements RuleRepository {
  const RuleRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Rule>> getRules(String homeId) async {
    final json = await _api.get('/v1/homes/$homeId/rules');
    return [
      for (final r in ApiClient.items(json))
        Rule(
          id: r['id'] as String,
          homeId: homeId,
          kind: r['kind'] == 'scene' ? RuleKind.scene : RuleKind.automation,
          name: r['name'] as String,
          enabled: r['enabled'] as bool? ?? true,
          icon: r['icon'] as String?,
          colorHex: r['color'] as String?,
          summary: r['summary'] as String?,
        ),
    ];
  }

  @override
  Future<void> runScene(String ruleId) =>
      _api.post('/v1/rules/$ruleId/run', idempotent: true);

  @override
  Future<void> setEnabled(String ruleId, {required bool enabled}) =>
      _api.put('/v1/rules/$ruleId/enabled', body: {'enabled': enabled});
}
