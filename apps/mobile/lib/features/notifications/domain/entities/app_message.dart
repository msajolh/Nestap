import 'package:equatable/equatable.dart';

enum MessageCategory { alarm, device, home, system, promo }

/// One entry in the message center (`notify.messages`).
class AppMessage extends Equatable {
  const AppMessage({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final MessageCategory category;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  AppMessage markRead() => AppMessage(
        id: id,
        category: category,
        title: title,
        body: body,
        createdAt: createdAt,
        read: true,
      );

  @override
  List<Object?> get props => [id, category, title, body, createdAt, read];
}
