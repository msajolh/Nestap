import '../entities/home.dart';

abstract interface class HomeRepository {
  Future<List<Home>> getHomes();

  Future<List<Room>> getRooms(String homeId);
}
