import '../entities/rule.dart';
import '../entities/rule_draft.dart';

abstract interface class RuleRepository {
  Future<List<Rule>> getRules(String homeId);

  Future<Rule> create(String homeId, RuleDraft draft);

  Future<void> runScene(String ruleId);

  Future<void> setEnabled(String ruleId, {required bool enabled});
}
