import '../core/errors/app_exceptions.dart';
import '../core/utils/json_reader.dart';
import 'activity_type.dart';

/// Actividad que el usuario planifica para una fecha y hora.
class PlannedActivity {
  const PlannedActivity({
    required this.id,
    required this.activity,
    required this.dateTime,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    this.placeName,
    this.placeLatitude,
    this.placeLongitude,
    this.notes,
  });

  final String id;
  final ActivityType activity;

  /// Fecha y hora elegidas por el usuario (hora local de su ubicación).
  final DateTime dateTime;

  /// Ciudad o ubicación para la que se planificó.
  final String locationName;
  final double latitude;
  final double longitude;

  /// Lugar concreto elegido (opcional).
  final String? placeName;
  final double? placeLatitude;
  final double? placeLongitude;
  final String? notes;

  PlannedActivity copyWith({
    ActivityType? activity,
    DateTime? dateTime,
    String? locationName,
    double? latitude,
    double? longitude,
    String? placeName,
    double? placeLatitude,
    double? placeLongitude,
    String? notes,
    bool clearPlace = false,
    bool clearNotes = false,
  }) {
    return PlannedActivity(
      id: id,
      activity: activity ?? this.activity,
      dateTime: dateTime ?? this.dateTime,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: clearPlace ? null : (placeName ?? this.placeName),
      placeLatitude: clearPlace ? null : (placeLatitude ?? this.placeLatitude),
      placeLongitude: clearPlace ? null : (placeLongitude ?? this.placeLongitude),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  factory PlannedActivity.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final dateText = json['dateTime'];
    final date = dateText is String ? DateTime.tryParse(dateText) : null;
    if (id is! String || date == null) {
      throw const UnexpectedResponseException('Plan guardado inválido.');
    }
    return PlannedActivity(
      id: id,
      activity: ActivityType.fromId(json['activity'] as String?),
      dateTime: date,
      locationName: json['locationName'] is String
          ? json['locationName'] as String
          : 'Ubicación',
      latitude: JsonReader.requiredDouble(json['latitude'], 'latitude'),
      longitude: JsonReader.requiredDouble(json['longitude'], 'longitude'),
      placeName: json['placeName'] is String ? json['placeName'] as String : null,
      placeLatitude: JsonReader.doubleOrNull(json['placeLatitude']),
      placeLongitude: JsonReader.doubleOrNull(json['placeLongitude']),
      notes: json['notes'] is String ? json['notes'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'activity': activity.id,
        'dateTime': dateTime.toIso8601String(),
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'placeName': placeName,
        'placeLatitude': placeLatitude,
        'placeLongitude': placeLongitude,
        'notes': notes,
      };
}
