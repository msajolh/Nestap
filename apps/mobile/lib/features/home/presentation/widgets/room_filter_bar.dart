import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/home.dart';
import '../../home_providers.dart';

/// Horizontal "All / Living Room / Bedroom …" chips.
class RoomFilterBar extends ConsumerWidget {
  const RoomFilterBar({required this.rooms, required this.padding, super.key});

  final List<Room> rooms;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRoomIdProvider);
    final notifier = ref.read(selectedRoomIdProvider.notifier);
    final options = <(String?, String)>[
      (null, 'All'),
      for (final room in rooms) (room.id, room.name),
    ];

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding.copyWith(top: AppSpacing.md, bottom: AppSpacing.md),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (id, name) = options[index];
          return ChoiceChip(
            label: Text(name),
            selected: selected == id,
            onSelected: (_) => notifier.select(id),
          );
        },
      ),
    );
  }
}
