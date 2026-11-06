import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../domain/entities/app_message.dart';
import '../../notifications_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(messagesProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: AsyncValueView(
        value: messages,
        onRetry: () => ref.invalidate(messagesProvider),
        data: (messages) {
          if (messages.isEmpty) {
            return const MessageView(
              icon: Icons.notifications_none_rounded,
              title: "You're all caught up",
              message: 'Alarms, offline devices and scene runs will show up here.',
            );
          }
          // Group by day label, keeping newest-first order.
          final groups = <String, List<AppMessage>>{};
          for (final m in messages) {
            groups.putIfAbsent(Formatters.day(m.createdAt), () => []).add(m);
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(messagesProvider.future),
            child: ListView(
              padding: EdgeInsets.all(context.pagePadding),
              children: [
                for (final MapEntry(key: day, value: items) in groups.entries)
                  ResponsiveCenter(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionLabel(day),
                        Card(
                          child: Column(
                            children: [
                              for (final (i, m) in items.indexed) ...[
                                if (i > 0) const Divider(indent: 72),
                                _MessageTile(message: m),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MessageTile extends ConsumerWidget {
  const _MessageTile({required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, color) = switch (message.category) {
      MessageCategory.alarm => (Icons.warning_amber_rounded, AppColors.error),
      MessageCategory.device => (Icons.cloud_off_rounded, AppColors.warning),
      MessageCategory.home => (Icons.auto_awesome_rounded, AppColors.brand),
      MessageCategory.system || MessageCategory.promo => (Icons.info_outline_rounded, AppColors.slate),
    };

    return ListTile(
      onTap: () => ref.read(messagesProvider.notifier).markRead(message),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(
        message.title,
        style: TextStyle(fontWeight: message.read ? FontWeight.w600 : FontWeight.w900),
      ),
      subtitle: Text('${message.body}\n${Formatters.time(message.createdAt)}'),
      isThreeLine: true,
      trailing: message.read
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppColors.cyan400, shape: BoxShape.circle),
            ),
      titleTextStyle: theme.textTheme.titleSmall,
    );
  }
}
