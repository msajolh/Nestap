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
    return [
      for (final r in ApiClient.items(json))
        Room(id: r['id'] as String, homeId: homeId, name: r['name'] as String),
    ];
  }
}
