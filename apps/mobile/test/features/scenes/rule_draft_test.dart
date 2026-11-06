import 'package:flutter_test/flutter_test.dart';
import 'package:nestap/core/utils/formatters.dart';
import 'package:nestap/features/scenes/data/rule_repository_impl.dart';
import 'package:nestap/features/scenes/domain/entities/rule.dart';
import 'package:nestap/features/scenes/domain/entities/rule_draft.dart';

void main() {
  const lightsOn = DeviceAction(deviceId: 'd1', dps: {'switch_1': true}, label: 'Lights · Turn on');

  group('RuleDraft.validate', () {
    test('a scene needs a name and a device action', () {
      const draft = RuleDraft(kind: RuleKind.scene);
      expect(draft.validate(), ['Give it a name.', 'Add at least one device action.']);
    });

    test('a delay alone is not enough', () {
      const draft = RuleDraft(kind: RuleKind.scene, name: 'Wait', actions: [DelayAction(60)]);
      expect(draft.validate(), ['Add at least one device action.']);
    });

    test('an automation also needs a condition', () {
      const draft = RuleDraft(kind: RuleKind.automation, name: 'Night', actions: [lightsOn]);
      expect(draft.validate(), ['Add at least one condition.']);
    });

    test('a complete automation is valid', () {
      const draft = RuleDraft(
        kind: RuleKind.automation,
        name: 'Night',
        conditions: [ScheduleCondition(hour: 18, minute: 30, days: [1, 2, 3, 4, 5])],
        actions: [lightsOn],
      );
      expect(draft.validate(), isEmpty);
    });
  });

  test('toJson follows the backend rule document', () {
    const draft = RuleDraft(
      kind: RuleKind.automation,
      name: '  Night  ',
      match: ConditionMatch.all,
      conditions: [ScheduleCondition(hour: 7, minute: 5, days: [6, 7])],
      actions: [lightsOn, DelayAction(300)],
    );
    final json = RuleRepositoryImpl.toJson(draft);
    expect(json['name'], 'Night');
    expect(json['match'], 'all');
    expect(json['conditions'], [
      {
        'type': 'schedule',
        'spec': {'type': 'weekly', 'time': '07:05', 'days': [6, 7]},
      },
    ]);
    expect(json['actions'], [
      {'type': 'device', 'device_id': 'd1', 'dps': {'switch_1': true}},
      {'type': 'delay', 'seconds': 300},
    ]);
  });

  test('repeat days read naturally', () {
    expect(Formatters.days([]), 'Once');
    expect(Formatters.days([1, 2, 3, 4, 5, 6, 7]), 'Every day');
    expect(Formatters.days([5, 1, 2, 3, 4]), 'Weekdays');
    expect(Formatters.days([7, 6]), 'Weekends');
    expect(Formatters.days([3, 1]), 'Mon, Wed');
  });
}
