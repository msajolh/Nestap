import 'package:equatable/equatable.dart';

class Home extends Equatable {
  const Home({required this.id, required this.name, required this.timezone});

  final String id;
  final String name;
  final String timezone;

  @override
  List<Object?> get props => [id, name, timezone];
}

class Room extends Equatable {
  const Room({required this.id, required this.homeId, required this.name});

  final String id;
  final String homeId;
  final String name;

  @override
  List<Object?> get props => [id, homeId, name];
}

enum HomeRole { owner, admin, member }

class HomeMember extends Equatable {
  const HomeMember({
    required this.userId,
    required this.displayName,
    required this.contact,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String contact;
  final HomeRole role;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? '?' : parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  List<Object?> get props => [userId, displayName, contact, role];
}

class Invitation extends Equatable {
  const Invitation({required this.code, required this.role, required this.expiresAt});

  final String code;
  final HomeRole role;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [code, role, expiresAt];
}
