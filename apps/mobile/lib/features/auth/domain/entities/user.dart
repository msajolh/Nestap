import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.displayName,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  String get contact => email ?? phone ?? '';

  @override
  List<Object?> get props => [id, displayName, email, phone, avatarUrl];
}
