import '../base_model.dart';

/// Represents a single GPS point in a workout route
class RoutePoint extends BaseModel {
  /// Latitude coordinate
  final double latitude;
  
  /// Longitude coordinate
  final double longitude;
  
  /// Altitude in meters (if available)
  final double? altitude;
  
  /// Speed at this point in meters per second (if available)
  final double? speed;
  
  /// The timestamp when the point was recorded
  final DateTime timestamp;
  
  /// The workout ID this route point belongs to
  final String workoutId;
  
  /// Seconds from the start of the workout
  final int offsetSeconds;
  
  /// Constructor
  RoutePoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    required this.timestamp,
    required this.workoutId,
    required this.offsetSeconds,
  });
  
  /// Create a RoutePoint from a JSON map
  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      altitude: json['altitude']?.toDouble(),
      speed: json['speed']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      workoutId: json['workoutId'],
      offsetSeconds: json['offsetSeconds'],
    );
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'workoutId': workoutId,
      'offsetSeconds': offsetSeconds,
    };
  }
}
