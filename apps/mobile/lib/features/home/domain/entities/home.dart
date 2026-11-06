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
