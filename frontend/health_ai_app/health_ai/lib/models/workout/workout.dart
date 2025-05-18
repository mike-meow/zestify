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

  /// Segment data containing kilometer/mile splits and detailed pace information
  final Map<String, dynamic>? segmentData;

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
    this.segmentData,
  });

  /// Create a Workout from a JSON map
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'],
      workoutType: json['type'] ?? json['workout_type'] ?? 'Unknown',
      startTime: DateTime.parse(json['startTime'] ?? json['start_date']),
      endTime: DateTime.parse(json['endTime'] ?? json['end_date']),
      durationInSeconds: json['durationInSeconds'] ?? json['duration_seconds'],
      energyBurned:
          (json['energyBurned'] ?? json['active_energy_burned'] ?? 0)
              .toDouble(),
      distance: json['distance']?.toDouble(),
      averageHeartRate:
          json['averageHeartRate']?.toDouble() ??
          (json['heart_rate_summary'] != null
              ? json['heart_rate_summary']['average']?.toDouble()
              : null),
      maxHeartRate:
          json['maxHeartRate']?.toDouble() ??
          (json['heart_rate_summary'] != null
              ? json['heart_rate_summary']['max']?.toDouble()
              : null),
      minHeartRate:
          json['minHeartRate']?.toDouble() ??
          (json['heart_rate_summary'] != null
              ? json['heart_rate_summary']['min']?.toDouble()
              : null),
      averagePace: json['averagePace']?.toDouble(),
      maxPace: json['maxPace']?.toDouble(),
      totalAscent: json['totalAscent']?.toDouble(),
      totalDescent: json['totalDescent']?.toDouble(),
      stepCount: json['stepCount'],
      cadence: json['cadence']?.toDouble(),
      power: json['power']?.toDouble(),
      source: json['source'] ?? 'Unknown',
      metadata: json['metadata'],
      segmentData: json['segment_data'] ?? json['segmentData'],
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
      segmentData: healthData['segment_data'],
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
      'segmentData': segmentData,
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
    // Only map RUNNING_SAND to RUNNING, keep everything else as is
    if (workoutType.toUpperCase() == 'RUNNING_SAND') {
      return 'RUNNING';
    }

    // Return the original type for all other workout types
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
    // Map RUNNING_SAND to running icon
    if (workoutType.toUpperCase() == 'RUNNING_SAND') {
      return 'running';
    }

    // For all other types, derive icon name from the workout type
    final typeLower = workoutType.toLowerCase();

    // Simple mapping for common workout types
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

    // Default to the original type or 'other' if no match
    return typeLower.isEmpty ? 'other' : typeLower;
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

  /// Check if this workout has segment data
  bool get hasSegmentData {
    return segmentData != null && segmentData!.isNotEmpty;
  }

  /// Get kilometer splits if available
  List<Map<String, dynamic>> get kilometerSplits {
    if (segmentData == null || !segmentData!.containsKey('kilometer_splits')) {
      return [];
    }

    return List<Map<String, dynamic>>.from(segmentData!['kilometer_splits']);
  }

  /// Get mile splits if available
  List<Map<String, dynamic>> get mileSplits {
    if (segmentData == null || !segmentData!.containsKey('mile_splits')) {
      return [];
    }

    return List<Map<String, dynamic>>.from(segmentData!['mile_splits']);
  }

  /// Get the most active segments based on pace
  List<Map<String, dynamic>> get mostActiveSegments {
    // Try kilometer splits first
    var splits = kilometerSplits;

    // If no kilometer splits, try mile splits
    if (splits.isEmpty) {
      splits = mileSplits;
    }

    // If we have splits, sort them by pace (ascending - faster pace is lower number)
    if (splits.isNotEmpty) {
      // Create a copy to avoid modifying the original data
      final sortedSplits = List<Map<String, dynamic>>.from(splits);
      sortedSplits.sort(
        (a, b) => (a['pace'] as double).compareTo(b['pace'] as double),
      );

      // Return the fastest 3 segments or all if less than 3
      return sortedSplits.take(3).toList();
    }

    return [];
  }

  /// Calculate estimated active duration based on segment data
  int get estimatedActiveDurationFromSegments {
    if (!hasSegmentData) {
      // Fall back to total duration if no segment data
      return durationInSeconds;
    }

    // If we have segment data, we can use the most active segments to estimate
    final activeSegments = mostActiveSegments;
    if (activeSegments.isEmpty) {
      // Fall back to total duration if no active segments found
      return durationInSeconds;
    }

    // Calculate average pace from the most active segments
    double totalPace = 0;
    for (final segment in activeSegments) {
      totalPace += segment['pace'] as double;
    }
    double averageActivePace = totalPace / activeSegments.length;

    // Estimate active duration based on distance and average active pace
    if (distance != null && distance! > 0) {
      // Convert from meters to kilometers for calculation
      final distanceInKm = distance! / 1000;

      // Calculate estimated active duration
      // average pace is in minutes per km, so multiply by distance in km to get minutes
      // then convert to seconds
      final activeMinutes = averageActivePace * distanceInKm;
      return (activeMinutes * 60).round();
    }

    // Fall back to 80% of total duration if calculation not possible
    return (durationInSeconds * 0.8).round();
  }

  /// Get active pace based on segment data
  double? get activePaceFromSegments {
    if (distance == null || distance! <= 0) return null;

    final activeDuration = estimatedActiveDurationFromSegments;
    // Convert seconds per meter to minutes per kilometer
    return (activeDuration / distance!) * (1000 / 60);
  }

  /// Get the formatted active pace based on segment data
  String get formattedActivePace {
    final pace = activePaceFromSegments;
    if (pace == null) return formattedPace; // Fall back to regular pace

    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Create a copy of this Workout with the given fields replaced with new values
  Workout copyWith({
    String? id,
    String? workoutType,
    DateTime? startTime,
    DateTime? endTime,
    int? durationInSeconds,
    double? energyBurned,
    double? distance,
    double? averageHeartRate,
    double? maxHeartRate,
    double? minHeartRate,
    double? averagePace,
    double? maxPace,
    double? totalAscent,
    double? totalDescent,
    int? stepCount,
    double? cadence,
    double? power,
    String? source,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? segmentData,
  }) {
    return Workout(
      id: id ?? this.id,
      workoutType: workoutType ?? this.workoutType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      energyBurned: energyBurned ?? this.energyBurned,
      distance: distance ?? this.distance,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      averagePace: averagePace ?? this.averagePace,
      maxPace: maxPace ?? this.maxPace,
      totalAscent: totalAscent ?? this.totalAscent,
      totalDescent: totalDescent ?? this.totalDescent,
      stepCount: stepCount ?? this.stepCount,
      cadence: cadence ?? this.cadence,
      power: power ?? this.power,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
      segmentData: segmentData ?? this.segmentData,
    );
  }
}
