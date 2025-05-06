import '../base_model.dart';

/// Represents a single workout session
class Workout extends BaseModel {
  /// Unique identifier for the workout
  final String id;

  /// Type of workout (original string from HealthKit)
  final String workoutType;

  /// Start time of the workout
  final DateTime startTime;

  /// End time of the workout
  final DateTime endTime;

  /// Duration in seconds
  final int durationInSeconds;

  /// Energy burned in calories
  final double energyBurned;

  /// Distance in meters (if applicable)
  final double? distance;

  /// Average heart rate (if available)
  final double? averageHeartRate;

  /// Maximum heart rate during workout (if available)
  final double? maxHeartRate;

  /// Minimum heart rate during workout (if available)
  final double? minHeartRate;

  /// Average pace in minutes per kilometer or mile (if applicable)
  final double? averagePace;

  /// Maximum pace achieved during workout (if applicable)
  final double? maxPace;

  /// Total elevation gain in meters (if applicable)
  final double? totalAscent;

  /// Total elevation loss in meters (if applicable)
  final double? totalDescent;

  /// Total steps taken during workout (if applicable)
  final int? stepCount;

  /// Average cadence in steps per minute (if applicable)
  final double? cadence;

  /// Average power output in watts (for cycling, if available)
  final double? power;

  /// Source of the workout data (e.g., "Apple Health", "Manual Entry")
  final String source;

  /// Additional metadata as key-value pairs
  final Map<String, dynamic>? metadata;

  Workout({
    required this.id,
    required this.workoutType,
    required this.startTime,
    required this.endTime,
    required this.durationInSeconds,
    required this.energyBurned,
    this.distance,
    this.averageHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.averagePace,
    this.maxPace,
    this.totalAscent,
    this.totalDescent,
    this.stepCount,
    this.cadence,
    this.power,
    required this.source,
    this.metadata,
  });

  /// Create a Workout from a JSON map
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'],
      workoutType: json['type'] ?? json['workout_type'] ?? 'Unknown',
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      durationInSeconds: json['durationInSeconds'],
      energyBurned: json['energyBurned'].toDouble(),
      distance: json['distance']?.toDouble(),
      averageHeartRate: json['averageHeartRate']?.toDouble(),
      maxHeartRate: json['maxHeartRate']?.toDouble(),
      minHeartRate: json['minHeartRate']?.toDouble(),
      averagePace: json['averagePace']?.toDouble(),
      maxPace: json['maxPace']?.toDouble(),
      totalAscent: json['totalAscent']?.toDouble(),
      totalDescent: json['totalDescent']?.toDouble(),
      stepCount: json['stepCount'],
      cadence: json['cadence']?.toDouble(),
      power: json['power']?.toDouble(),
      source: json['source'],
      metadata: json['metadata'],
    );
  }

  /// Create a Workout from Apple Health data
  factory Workout.fromAppleHealth(Map<String, dynamic> healthData) {
    // Calculate duration if not provided
    final durationInSeconds =
        healthData['durationInSeconds'] ??
        DateTime.parse(
          healthData['endDate'],
        ).difference(DateTime.parse(healthData['startDate'])).inSeconds;

    // Calculate pace if distance is available (minutes per kilometer)
    double? averagePace;
    if (healthData['totalDistance'] != null &&
        healthData['totalDistance'] > 0) {
      // Convert seconds per meter to minutes per kilometer
      averagePace =
          (durationInSeconds / healthData['totalDistance']) * (1000 / 60);
    }

    // Get the raw workout type directly from HealthKit
    final rawWorkoutType =
        healthData['workoutActivityTypeEnum'] ??
        healthData['workoutActivityType'] ??
        'Unknown';

    return Workout(
      id: healthData['uuid'] ?? healthData['id'],
      workoutType: rawWorkoutType,
      startTime: DateTime.parse(healthData['startDate']),
      endTime: DateTime.parse(healthData['endDate']),
      durationInSeconds: durationInSeconds,
      energyBurned: healthData['totalEnergyBurned']?.toDouble() ?? 0.0,
      distance: healthData['totalDistance']?.toDouble(),
      averageHeartRate: healthData['averageHeartRate']?.toDouble(),
      maxHeartRate: healthData['maxHeartRate']?.toDouble(),
      minHeartRate: healthData['minHeartRate']?.toDouble(),
      averagePace: averagePace,
      maxPace: healthData['maxPace']?.toDouble(),
      totalAscent: healthData['totalAscent']?.toDouble(),
      totalDescent: healthData['totalDescent']?.toDouble(),
      stepCount: healthData['stepCount'],
      cadence: healthData['cadence']?.toDouble(),
      power: healthData['power']?.toDouble(),
      source: 'Apple Health',
      metadata: {
        'sourceRevision': healthData['sourceRevision'],
        'device': healthData['device'],
        'recordingMethod': healthData['recordingMethod'],
      },
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': workoutType,
      'workout_type': workoutType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationInSeconds': durationInSeconds,
      'energyBurned': energyBurned,
      'distance': distance,
      'averageHeartRate': averageHeartRate,
      'maxHeartRate': maxHeartRate,
      'minHeartRate': minHeartRate,
      'averagePace': averagePace,
      'maxPace': maxPace,
      'totalAscent': totalAscent,
      'totalDescent': totalDescent,
      'stepCount': stepCount,
      'cadence': cadence,
      'power': power,
      'source': source,
      'metadata': metadata,
    };
  }

  /// Get the duration as a formatted string (e.g., "1h 30m")
  String get formattedDuration {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get the distance in kilometers as a formatted string (e.g., "5.2 km")
  String get formattedDistance {
    if (distance == null) return 'N/A';

    final distanceInKm = distance! / 1000;
    return '${distanceInKm.toStringAsFixed(1)} km';
  }

  /// Get the calories burned as a formatted string (e.g., "250 cal")
  String get formattedCalories {
    return '${energyBurned.round()} cal';
  }

  /// Normalize workout types from various sources to a standard set
  String get normalizedType {
    final typeLower = workoutType.toLowerCase();
    
    // Map specific running types to general "RUNNING"
    if (typeLower.contains('run') || typeLower.contains('runn')) {
      return 'RUNNING';
    }
    
    // Return the original type if no mapping exists
    return workoutType;
  }

  /// Get a human-readable display name for the workout type
  String get displayName {
    // Use normalized type to ensure consistent naming
    final normalizedWorkoutType = normalizedType;
    
    // Convert workout type to a readable format (e.g., "RUNNING" -> "Running")
    return normalizedWorkoutType
        .split('_')
        .map(
          (word) =>
              word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : '',
        )
        .join(' ');
  }

  /// Get an icon asset name based on the workout type
  String get iconAsset {
    // Use normalized type for consistent icon mapping
    final typeLower = normalizedType.toLowerCase();

    if (typeLower.contains('run')) {
      return 'running';
    }
    if (typeLower.contains('walk')) {
      return 'walking';
    }
    if (typeLower.contains('cycl') || typeLower.contains('bik')) {
      return 'cycling';
    }
    if (typeLower.contains('swim')) {
      return 'swimming';
    }
    if (typeLower.contains('hik')) {
      return 'hiking';
    }
    if (typeLower.contains('yoga')) {
      return 'yoga';
    }
    if (typeLower.contains('strength') || typeLower.contains('weight')) {
      return 'strength';
    }
    if (typeLower.contains('hiit') || typeLower.contains('interval')) {
      return 'hiit';
    }
    if (typeLower.contains('pilates')) {
      return 'pilates';
    }
    if (typeLower.contains('danc')) {
      return 'dance';
    }
    if (typeLower.contains('function')) {
      return 'functional';
    }
    if (typeLower.contains('traditional')) {
      return 'traditional';
    }
    if (typeLower.contains('core')) {
      return 'core';
    }
    if (typeLower.contains('flex')) {
      return 'flexibility';
    }
    if (typeLower.contains('elliptical')) {
      return 'elliptical';
    }
    if (typeLower.contains('stair')) {
      return 'stairs';
    }
    if (typeLower.contains('row')) {
      return 'rowing';
    }

    return 'other';
  }

  /// Get the average pace as a formatted string (e.g., "5:30 /km")
  String get formattedPace {
    if (averagePace == null) return 'N/A';

    final minutes = averagePace!.floor();
    final seconds = ((averagePace! - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Get the max pace as a formatted string (e.g., "4:45 /km")
  String get formattedMaxPace {
    if (maxPace == null) return 'N/A';

    final minutes = maxPace!.floor();
    final seconds = ((maxPace! - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Get the elevation gain as a formatted string (e.g., "85m")
  String get formattedElevation {
    if (totalAscent == null && totalDescent == null) return 'N/A';

    final ascent = totalAscent != null ? '${totalAscent!.round()}m ↑' : '';
    final descent = totalDescent != null ? '${totalDescent!.round()}m ↓' : '';

    if (ascent.isNotEmpty && descent.isNotEmpty) {
      return '$ascent $descent';
    } else {
      return ascent.isNotEmpty ? ascent : descent;
    }
  }

  /// Get the cadence as a formatted string (e.g., "175 spm")
  String get formattedCadence {
    if (cadence == null) return 'N/A';
    return '${cadence!.round()} spm';
  }

  /// Get the power as a formatted string (e.g., "250W")
  String get formattedPower {
    if (power == null) return 'N/A';
    return '${power!.round()}W';
  }

  /// Get the heart rate range as a formatted string (e.g., "95-175 bpm")
  String get formattedHeartRateRange {
    if (minHeartRate == null && maxHeartRate == null) {
      return averageHeartRate != null
          ? '${averageHeartRate!.round()} bpm'
          : 'N/A';
    }

    final min = minHeartRate != null ? minHeartRate!.round().toString() : '?';
    final max = maxHeartRate != null ? maxHeartRate!.round().toString() : '?';

    return '$min-$max bpm';
  }

  /// Check if this is an outdoor workout type that would have GPS route data
  bool get isOutdoorWorkout {
    final typeLower = workoutType.toLowerCase();

    // Workout types that are typically done outdoors and might have GPS data
    return typeLower.contains('run') ||
        typeLower.contains('walk') ||
        typeLower.contains('hik') ||
        typeLower.contains('cycl') ||
        typeLower.contains('bik') ||
        typeLower.contains('swim') && !typeLower.contains('pool');
  }
}
