import '../../../core/network/api_client.dart';
import '../domain/entities/home.dart';
import '../domain/repositories/home_repository.dart';

/// Small feature, so data source, DTO mapping and repository share one file.
class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Home>> getHomes() async {
    final json = await _api.get('/v1/homes');
    return [
      for (final h in ApiClient.items(json))
        Home(
          id: h['id'] as String,
          name: h['name'] as String,
          timezone: h['timezone'] as String? ?? 'UTC',
        ),
    ];
  }

  @override
  Future<List<Room>> getRooms(String homeId) async {
    final json = await _api.get('/v1/homes/$homeId/rooms');
    return [for (final r in ApiClient.items(json)) _room(r, homeId)];
  }

  @override
  Future<Room> addRoom(String homeId, String name) async =>
      _room(await _api.post('/v1/homes/$homeId/rooms', body: {'name': name}, idempotent: true), homeId);

  @override
  Future<void> renameRoom(Room room, String name) =>
      _api.patch('/v1/homes/${room.homeId}/rooms/${room.id}', body: {'name': name});

  @override
  Future<void> deleteRoom(Room room) => _api.delete('/v1/homes/${room.homeId}/rooms/${room.id}');

  @override
  Future<List<HomeMember>> getMembers(String homeId) async {
    final json = await _api.get('/v1/homes/$homeId/members');
    return [
      for (final m in ApiClient.items(json))
        HomeMember(
          userId: m['user_id'] as String,
          displayName: m['display_name'] as String? ?? '',
          contact: m['contact'] as String? ?? '',
          role: _role(m['role']),
        ),
    ];
  }

  @override
  Future<Invitation> createInvitation(String homeId, {HomeRole role = HomeRole.member}) async {
    final json = await _api.post(
      '/v1/homes/$homeId/invitations',
      body: {'role': role.name},
      idempotent: true,
    );
    return Invitation(
      code: json['code'] as String,
      role: _role(json['role']),
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
    );
  }

  static Room _room(JsonMap r, String homeId) =>
      Room(id: r['id'] as String, homeId: homeId, name: r['name'] as String);

  static HomeRole _role(Object? value) => HomeRole.values.asNameMap()[value] ?? HomeRole.member;
}
