import 'rule.dart';

/// "If" side of an automation.
sealed class RuleCondition {
  const RuleCondition();
}

/// At a time of day on some weekdays (1 = Monday … 7 = Sunday).
final class ScheduleCondition extends RuleCondition {
  const ScheduleCondition({required this.hour, required this.minute, required this.days});

  final int hour;
  final int minute;
  final List<int> days;
}

/// When an on/off DP of a device becomes [value].
final class DeviceStateCondition extends RuleCondition {
  const DeviceStateCondition({
    required this.deviceId,
    required this.dp,
    required this.value,
    required this.label,
  });

  final String deviceId;
  final String dp;
  final bool value;

  /// "Hall PIR · Switch 1 on", shown in the editor.
  final String label;
}

/// "Then" side of a scene or automation.
sealed class RuleAction {
  const RuleAction();
}

final class DeviceAction extends RuleAction {
  const DeviceAction({required this.deviceId, required this.dps, required this.label});

  final String deviceId;
  final Map<String, Object?> dps;
  final String label;
}

final class DelayAction extends RuleAction {
  const DelayAction(this.seconds);

  final int seconds;
}

enum ConditionMatch { any, all }

/// Everything the editor collects before saving.
class RuleDraft {
  const RuleDraft({
    required this.kind,
    this.name = '',
    this.icon = 'sunny',
    this.colorHex = '#00D3F3',
    this.match = ConditionMatch.any,
    this.conditions = const [],
    this.actions = const [],
  });

  final RuleKind kind;
  final String name;
  final String icon;
  final String colorHex;
  final ConditionMatch match;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;

  /// Problems to show the user; empty means it can be saved.
  List<String> validate() => [
        if (name.trim().isEmpty) 'Give it a name.',
        if (kind == RuleKind.automation && conditions.isEmpty) 'Add at least one condition.',
        if (!actions.any((a) => a is DeviceAction)) 'Add at least one device action.',
      ];

  RuleDraft copyWith({
    String? name,
    String? icon,
    String? colorHex,
    ConditionMatch? match,
    List<RuleCondition>? conditions,
    List<RuleAction>? actions,
  }) =>
      RuleDraft(
        kind: kind,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        colorHex: colorHex ?? this.colorHex,
        match: match ?? this.match,
        conditions: conditions ?? this.conditions,
        actions: actions ?? this.actions,
      );
}
