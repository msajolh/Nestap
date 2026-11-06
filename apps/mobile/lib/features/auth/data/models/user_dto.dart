import '../../domain/entities/user.dart';

/// Wire format of `GET /v1/users/me`.
class UserDto {
  const UserDto(this.json);

  final Map<String, dynamic> json;

  User toDomain() => User(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  static Map<String, dynamic> fromDomain(User user) => {
        'id': user.id,
        'display_name': user.displayName,
        'email': user.email,
        'phone': user.phone,
        'avatar_url': user.avatarUrl,
      };
}
