import '../base_model.dart';

/// Represents a single heart rate measurement during a workout
class HeartRateSample extends BaseModel {
  /// The heart rate value in beats per minute
  final double value;
  
  /// The timestamp when the measurement was taken
  final DateTime timestamp;
  
  /// The workout ID this sample belongs to
  final String workoutId;
  
  /// Seconds from the start of the workout
  final int offsetSeconds;
  
  /// Constructor
  HeartRateSample({
    required this.value,
    required this.timestamp,
    required this.workoutId,
    required this.offsetSeconds,
  });
  
  /// Create a HeartRateSample from a JSON map
  factory HeartRateSample.fromJson(Map<String, dynamic> json) {
    return HeartRateSample(
      value: json['value'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      workoutId: json['workoutId'],
      offsetSeconds: json['offsetSeconds'],
    );
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'workoutId': workoutId,
      'offsetSeconds': offsetSeconds,
    };
  }
}
