import '../entities/home.dart';

abstract interface class HomeRepository {
  Future<List<Home>> getHomes();

  Future<List<Room>> getRooms(String homeId);

  Future<Room> addRoom(String homeId, String name);

  Future<void> renameRoom(Room room, String name);

  /// Devices in the room stay in the home, without a room.
  Future<void> deleteRoom(Room room);

  Future<List<HomeMember>> getMembers(String homeId);

  Future<Invitation> createInvitation(String homeId, {HomeRole role = HomeRole.member});
}
