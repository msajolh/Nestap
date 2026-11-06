import '../../domain/entities/device.dart';

/// Wire format of one item in `GET /v1/homes/{id}/devices`.
class DeviceDto {
  const DeviceDto(this.json);

  final Map<String, dynamic> json;

  Device toDomain() => Device(
        id: json['id'] as String,
        homeId: json['home_id'] as String,
        roomId: json['room_id'] as String?,
        name: json['name'] as String,
        category: DeviceCategory.fromCode(json['category'] as String? ?? ''),
        productId: json['product_id'] as String? ?? '',
        online: json['online'] as bool? ?? false,
        state: Map<String, Object?>.of(
          (json['state'] as Map<String, dynamic>?) ?? const {},
        ),
        version: (json['version'] as num?)?.toInt() ?? 0,
        transport: json['transport'] as String? ?? 'nestap_mqtt',
      );
}
