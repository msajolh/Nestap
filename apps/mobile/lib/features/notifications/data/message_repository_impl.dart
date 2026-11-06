import '../../../core/network/api_client.dart';
import '../domain/entities/app_message.dart';
import '../domain/repositories/message_repository.dart';

class MessageRepositoryImpl implements MessageRepository {
  const MessageRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<AppMessage>> getMessages() async {
    final json = await _api.get('/v1/messages');
    return [
      for (final m in ApiClient.items(json))
        AppMessage(
          id: m['id'] as String,
          category: MessageCategory.values.asNameMap()[m['category']] ?? MessageCategory.system,
          title: m['title'] as String? ?? '',
          body: m['body'] as String? ?? '',
          createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
          read: m['read'] as bool? ?? false,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markRead([List<String>? ids]) =>
      _api.post('/v1/messages/read', body: ids == null ? {'all': true} : {'ids': ids});
}
