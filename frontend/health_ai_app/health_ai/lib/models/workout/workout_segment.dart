import '../base_model.dart';

/// Enum representing different segment types
enum WorkoutSegmentType {
  lap,
  interval,
  warmup,
  cooldown,
  recovery,
  custom,
}

/// Extension to provide human-readable names for segment types
extension WorkoutSegmentTypeExtension on WorkoutSegmentType {
  String get displayName {
    switch (this) {
      case WorkoutSegmentType.lap:
        return 'Lap';
      case WorkoutSegmentType.interval:
        return 'Interval';
      case WorkoutSegmentType.warmup:
        return 'Warm Up';
      case WorkoutSegmentType.cooldown:
        return 'Cool Down';
      case WorkoutSegmentType.recovery:
        return 'Recovery';
      case WorkoutSegmentType.custom:
        return 'Custom';
    }
  }
}

/// Represents a segment or interval within a workout
class WorkoutSegment extends BaseModel {
  /// Unique identifier for the segment
  final String id;
  
  /// The workout ID this segment belongs to
  final String workoutId;
  
  /// Index of the segment within the workout
  final int index;
  
  /// Type of segment
  final WorkoutSegmentType type;
  
  /// Custom name for the segment (if any)
  final String? name;
  
  /// Start time of the segment
  final DateTime startTime;
  
  /// End time of the segment
  final DateTime endTime;
  
  /// Duration in seconds
  final int durationInSeconds;
  
  /// Distance covered in this segment in meters (if applicable)
  final double? distance;
  
  /// Average pace for this segment (if applicable)
  final double? averagePace;
  
  /// Average heart rate during this segment (if available)
  final double? averageHeartRate;
  
  /// Constructor
  WorkoutSegment({
    required this.id,
    required this.workoutId,
    required this.index,
    required this.type,
    this.name,
    required this.startTime,
    required this.endTime,
    required this.durationInSeconds,
    this.distance,
    this.averagePace,
    this.averageHeartRate,
  });
  
  /// Create a WorkoutSegment from a JSON map
  factory WorkoutSegment.fromJson(Map<String, dynamic> json) {
    return WorkoutSegment(
      id: json['id'],
      workoutId: json['workoutId'],
      index: json['index'],
      type: WorkoutSegmentType.values.firstWhere(
        (e) => e.toString() == 'WorkoutSegmentType.${json['type']}',
        orElse: () => WorkoutSegmentType.custom,
      ),
      name: json['name'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      durationInSeconds: json['durationInSeconds'],
      distance: json['distance']?.toDouble(),
      averagePace: json['averagePace']?.toDouble(),
      averageHeartRate: json['averageHeartRate']?.toDouble(),
    );
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workoutId': workoutId,
      'index': index,
      'type': type.toString().split('.').last,
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationInSeconds': durationInSeconds,
      'distance': distance,
      'averagePace': averagePace,
      'averageHeartRate': averageHeartRate,
    };
  }
  
  /// Get the duration as a formatted string (e.g., "5:30")
  String get formattedDuration {
    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Get the pace as a formatted string (e.g., "5:30 /km")
  String get formattedPace {
    if (averagePace == null) return 'N/A';
    
    final minutes = averagePace!.floor();
    final seconds = ((averagePace! - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }
  
  /// Get the distance as a formatted string (e.g., "1.2 km")
  String get formattedDistance {
    if (distance == null) return 'N/A';
    
    final distanceInKm = distance! / 1000;
    return '${distanceInKm.toStringAsFixed(1)} km';
  }
}
