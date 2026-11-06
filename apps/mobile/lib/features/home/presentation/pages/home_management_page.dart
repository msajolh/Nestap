import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../devices/presentation/providers/home_devices_controller.dart';
import '../../domain/entities/home.dart';
import '../../home_providers.dart';

/// Rooms and members of the current home.
class HomeManagementPage extends ConsumerWidget {
  const HomeManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(currentHomeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(home.value?.name ?? 'Home')),
      body: AsyncValueView(
        value: home,
        onRetry: () => ref.invalidate(homesProvider),
        data: (home) => home == null
            ? const MessageView(icon: Icons.home_work_outlined, title: 'No home yet')
            : ListView(
                padding: EdgeInsets.all(context.pagePadding),
                children: [
                  ResponsiveCenter(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RoomsSection(home: home),
                        _MembersSection(home: home),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RoomsSection extends ConsumerWidget {
  const _RoomsSection({required this.home});

  final Home home;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await action();
      container
        ..invalidate(roomsProvider)
        ..invalidate(homeDevicesProvider);
    } on Object catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final devices = ref.watch(homeDevicesProvider).value ?? const [];
    final repository = ref.read(homeRepositoryProvider);

    Future<void> addRoom() async {
      final name = await showTextInputDialog(context, title: 'New room', label: 'Room name', confirm: 'Add');
      if (name != null && context.mounted) {
        await _run(context, () => repository.addRoom(home.id, name));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Rooms',
          trailing: TextButton.icon(
            onPressed: addRoom,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
        Card(
          child: rooms.isEmpty
              ? const ListTile(title: Text('No rooms yet'))
              : Column(
                  children: [
                    for (final (i, room) in rooms.indexed) ...[
                      if (i > 0) const Divider(indent: 56),
                      ListTile(
                        leading: const Icon(Icons.meeting_room_outlined),
                        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(_deviceCount(devices.where((d) => d.roomId == room.id).length)),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Room options',
                          onSelected: (choice) async {
                            if (choice == 'rename') {
                              final name = await showTextInputDialog(
                                context,
                                title: 'Rename room',
                                label: 'Room name',
                                initial: room.name,
                              );
                              if (name != null && context.mounted) {
                                await _run(context, () => repository.renameRoom(room, name));
                              }
                            } else {
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Delete ${room.name}?',
                                message: 'Its devices stay in the home without a room.',
                                confirm: 'Delete',
                                destructive: true,
                              );
                              if (ok && context.mounted) {
                                await _run(context, () => repository.deleteRoom(room));
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static String _deviceCount(int n) => n == 1 ? '1 device' : '$n devices';
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection({required this.home});

  final Home home;

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    try {
      final invitation = await ref.read(homeRepositoryProvider).createInvitation(home.id);
      if (!context.mounted) return;
      await showAppSheet<void>(
        context,
        title: 'Invite to ${home.name}',
        builder: (context) => _InvitationSheet(invitation: invitation),
      );
    } on Object catch (e) {
      if (context.mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Members'),
        Card(
          child: members.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ListTile(title: Text(messageFor(e))),
            data: (members) => Column(
              children: [
                for (final (i, m) in members.indexed) ...[
                  if (i > 0) const Divider(indent: 72),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.cyan400,
                      foregroundColor: AppColors.navy,
                      child: Text(m.initials, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    title: Text(m.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(m.contact),
                    trailing: _RoleChip(role: m.role),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => _invite(context, ref),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Invite member'),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final HomeRole role;

  @override
  Widget build(BuildContext context) {
    final owner = role == HomeRole.owner;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: owner ? AppColors.cyan400 : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.all(AppRadius.lg),
      ),
      child: Text(
        switch (role) {
          HomeRole.owner => 'Owner',
          HomeRole.admin => 'Admin',
          HomeRole.member => 'Member',
        },
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: owner ? AppColors.navy : null,
        ),
      ),
    );
  }
}

class _InvitationSheet extends StatelessWidget {
  const _InvitationSheet({required this.invitation});

  final Invitation invitation;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final expires = '${Formatters.day(invitation.expiresAt)} ${Formatters.time(invitation.expiresAt)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Share this code with the person you want to add to your home.',
          style: text.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xl),
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.all(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: SelectableText(
              invitation.code,
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Valid until $expires', style: text.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invitation.code));
            if (context.mounted) context.showMessage('Code copied');
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy code'),
        ),
      ],
    );
  }
}
