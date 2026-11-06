import 'package:equatable/equatable.dart';

enum RuleKind { scene, automation }

/// A tap-to-run scene or a condition-triggered automation
/// (`automation.rules` in the backend).
class Rule extends Equatable {
  const Rule({
    required this.id,
    required this.homeId,
    required this.kind,
    required this.name,
    required this.enabled,
    this.icon,
    this.colorHex,
    this.summary,
  });

  final String id;
  final String homeId;
  final RuleKind kind;
  final String name;
  final bool enabled;
  final String? icon;
  final String? colorHex;

  /// Human description of the trigger, e.g. "Every day · 23:00".
  final String? summary;

  Rule copyWith({bool? enabled}) => Rule(
        id: id,
        homeId: homeId,
        kind: kind,
        name: name,
        enabled: enabled ?? this.enabled,
        icon: icon,
        colorHex: colorHex,
        summary: summary,
      );

  @override
  List<Object?> get props => [id, homeId, kind, name, enabled, icon, colorHex, summary];
}
