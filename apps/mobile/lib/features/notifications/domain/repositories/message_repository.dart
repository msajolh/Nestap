import '../entities/app_message.dart';

abstract interface class MessageRepository {
  /// Newest first.
  Future<List<AppMessage>> getMessages();

  /// Marks [ids] read, or everything when [ids] is null.
  Future<void> markRead([List<String>? ids]);
}
