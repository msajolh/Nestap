import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/message_repository_impl.dart';
import 'domain/entities/app_message.dart';
import 'domain/repositories/message_repository.dart';

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepositoryImpl(ref.watch(apiClientProvider)),
);

final messagesProvider = AsyncNotifierProvider<MessagesController, List<AppMessage>>(
  MessagesController.new,
);

class MessagesController extends AsyncNotifier<List<AppMessage>> {
  @override
  Future<List<AppMessage>> build() => ref.watch(messageRepositoryProvider).getMessages();

  Future<void> markRead(AppMessage message) async {
    if (message.read) return;
    _apply((m) => m.id == message.id);
    await ref.read(messageRepositoryProvider).markRead([message.id]);
  }

  Future<void> markAllRead() async {
    _apply((_) => true);
    await ref.read(messageRepositoryProvider).markRead();
  }

  void _apply(bool Function(AppMessage) where) {
    final messages = state.value;
    if (messages == null) return;
    state = AsyncData([for (final m in messages) where(m) ? m.markRead() : m]);
  }
}

/// Badge count on the dashboard bell.
final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(messagesProvider).value?.where((m) => !m.read).length ?? 0,
);
