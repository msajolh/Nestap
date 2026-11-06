import '../entities/rule.dart';

abstract interface class RuleRepository {
  Future<List<Rule>> getRules(String homeId);

  Future<void> runScene(String ruleId);

  Future<void> setEnabled(String ruleId, {required bool enabled});
}
