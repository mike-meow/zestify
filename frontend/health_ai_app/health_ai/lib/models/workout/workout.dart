import 'package:flutter/foundation.dart';
import '../base_model.dart';

/// Enum representing different workout types
enum WorkoutType {
  running,
  walking,
  cycling,
  swimming,
  hiking,
  yoga,
  strengthTraining,
  highIntensityIntervalTraining,
  pilates,
  dance,
  functionalTraining,
  traditionalStrengthTraining,
  coreTraining,
  flexibility,
  elliptical,
  stairClimbing,
  rowing,
  other,
}

/// Extension to provide human-readable names for workout types
extension WorkoutTypeExtension on WorkoutType {
  String get displayName {
    switch (this) {
      case WorkoutType.running:
        return 'Running';
      case WorkoutType.walking:
        return 'Walking';
      case WorkoutType.cycling:
        return 'Cycling';
      case WorkoutType.swimming:
        return 'Swimming';
      case WorkoutType.hiking:
        return 'Hiking';
      case WorkoutType.yoga:
        return 'Yoga';
      case WorkoutType.strengthTraining:
        return 'Strength Training';
      case WorkoutType.highIntensityIntervalTraining:
        return 'HIIT';
      case WorkoutType.pilates:
        return 'Pilates';
      case WorkoutType.dance:
        return 'Dance';
      case WorkoutType.functionalTraining:
        return 'Functional Training';
      case WorkoutType.traditionalStrengthTraining:
        return 'Traditional Strength';
      case WorkoutType.coreTraining:
        return 'Core Training';
      case WorkoutType.flexibility:
        return 'Flexibility';
      case WorkoutType.elliptical:
        return 'Elliptical';
      case WorkoutType.stairClimbing:
        return 'Stair Climbing';
      case WorkoutType.rowing:
        return 'Rowing';
      case WorkoutType.other:
        return 'Other';
    }
  }

  /// Get icon data for this workout type
  String get iconAsset {
    switch (this) {
      case WorkoutType.running:
        return 'running';
      case WorkoutType.walking:
        return 'walking';
      case WorkoutType.cycling:
        return 'cycling';
      case WorkoutType.swimming:
        return 'swimming';
      case WorkoutType.hiking:
        return 'hiking';
      case WorkoutType.yoga:
        return 'yoga';
      case WorkoutType.strengthTraining:
        return 'strength';
      case WorkoutType.highIntensityIntervalTraining:
        return 'hiit';
      case WorkoutType.pilates:
        return 'pilates';
      case WorkoutType.dance:
        return 'dance';
      case WorkoutType.functionalTraining:
        return 'functional';
      case WorkoutType.traditionalStrengthTraining:
        return 'traditional';
      case WorkoutType.coreTraining:
        return 'core';
      case WorkoutType.flexibility:
        return 'flexibility';
      case WorkoutType.elliptical:
        return 'elliptical';
      case WorkoutType.stairClimbing:
        return 'stairs';
      case WorkoutType.rowing:
        return 'rowing';
      case WorkoutType.other:
        return 'other';
    }
  }
}

/// Represents a single workout session
class Workout extends BaseModel {
  /// Unique identifier for the workout
  final String id;

  /// Type of workout
  final WorkoutType type;

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
    required this.type,
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
      type: WorkoutType.values.firstWhere(
        (e) => e.toString() == 'WorkoutType.${json['type']}',
        orElse: () => WorkoutType.other,
      ),
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

    return Workout(
      id: healthData['uuid'] ?? healthData['id'],
      type: _mapAppleWorkoutType(
        healthData['workoutActivityTypeEnum'] ??
            healthData['workoutActivityType'],
      ),
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

  /// Map Apple Health workout type to our WorkoutType enum
  static WorkoutType _mapAppleWorkoutType(String? appleWorkoutType) {
    if (appleWorkoutType == null) return WorkoutType.other;

    // Normalize to lowercase for case-insensitive matching
    final String typeLower = appleWorkoutType.toLowerCase();

    // Log the normalized type being mapped
    debugPrint('Mapping workout type (normalized): $typeLower from original: $appleWorkoutType');

    // Direct mapping from HealthWorkoutActivityType enum strings (or common variations)
    switch (typeLower) {
      case 'running':
      case 'run':
      case 'running_jogging': // Added common variation
      case 'running_sand': // Added from user data
      case 'running_treadmill': // Added from user data
        return WorkoutType.running;

      case 'walking':
      case 'walk':
        return WorkoutType.walking;

      case 'cycling':
      case 'bike':
      case 'biking':
        return WorkoutType.cycling;

      case 'swimming':
      case 'swim':
        return WorkoutType.swimming;

      case 'hiking':
      case 'hike':
        return WorkoutType.hiking;

      case 'yoga':
        return WorkoutType.yoga;

      // --- Explicit Strength Training Variations --- 
      case 'strength_training': // Generic term
      case 'traditional_strength_training':
      case 'weight_lifting': // Common alternative term
        return WorkoutType.traditionalStrengthTraining;
      case 'functional_strength_training':
        return WorkoutType.functionalTraining;
      case 'core_training':
        return WorkoutType.coreTraining;
      // --- End Strength --- 

      case 'high_intensity_interval_training':
      case 'hiit':
        return WorkoutType.highIntensityIntervalTraining;

      case 'pilates':
        return WorkoutType.pilates;

      case 'dance':
      case 'dancing':
        return WorkoutType.dance;

      case 'flexibility':
        return WorkoutType.flexibility;

      case 'elliptical':
        return WorkoutType.elliptical;

      case 'stair_climbing':
      case 'stairs':
        return WorkoutType.stairClimbing;

      case 'rowing':
      case 'row':
        return WorkoutType.rowing;
        
      // Add other explicit types found in logs or known from HealthKit
      case 'basketball': // Added from user data logs if available
        // Decide if this maps to 'other' or a new category if needed
        debugPrint('Mapping specific type \'basketball\' to other for now.');
        return WorkoutType.other; // Or create a specific enum if desired

      default:
        // Temporarily simplified to isolate the error
        debugPrint('Unknown workout type: $appleWorkoutType, defaulting to other');
        return WorkoutType.other;
        
        /* --- Original Fallback Logic --- 
        // Fallback: Check if the original string contains keywords
        // Use the *original* non-lowercased string for potential specific names
        // that might lose meaning in lowercase (though unlikely here)
        // Keep using typeLower for contains checks for simplicity unless needed
        
        debugPrint('Workout type \'$typeLower\' not in direct map, trying fallback...');
        
        if (typeLower.contains('strength') || typeLower.contains('weight')) {
          debugPrint('Fallback mapping \'$typeLower\' to traditionalStrengthTraining');
          return WorkoutType.traditionalStrengthTraining;
        } else if (typeLower.contains('run')) {
          debugPrint('Fallback mapping \'$typeLower\' to running');
          return WorkoutType.running;
        } else if (typeLower.contains('walk')) {
          debugPrint('Fallback mapping \'$typeLower\' to walking');
          return WorkoutType.walking;
        } else if (typeLower.contains('cycl') || typeLower.contains('bik')) {
           debugPrint('Fallback mapping \'$typeLower\' to cycling');
          return WorkoutType.cycling;
        } else if (typeLower.contains('swim')) {
           debugPrint('Fallback mapping \'$typeLower\' to swimming');
          return WorkoutType.swimming;
        } else if (typeLower.contains('hik')) {
           debugPrint('Fallback mapping \'$typeLower\' to hiking');
          return WorkoutType.hiking;
        } else if (typeLower.contains('yoga')) {
           debugPrint('Fallback mapping \'$typeLower\' to yoga');
          return WorkoutType.yoga;
        } else if (typeLower.contains('interval') || typeLower.contains('hiit')) {
           debugPrint('Fallback mapping \'$typeLower\' to highIntensityIntervalTraining');
          return WorkoutType.highIntensityIntervalTraining;
        } else if (typeLower.contains('pilates')) {
           debugPrint('Fallback mapping \'$typeLower\' to pilates');
          return WorkoutType.pilates;
        } else if (typeLower.contains('danc')) {
           debugPrint('Fallback mapping \'$typeLower\' to dance');
          return WorkoutType.dance;
        } else if (typeLower.contains('function')) {
           debugPrint('Fallback mapping \'$typeLower\' to functionalTraining');
          return WorkoutType.functionalTraining;
        } else if (typeLower.contains('core')) {
           debugPrint('Fallback mapping \'$typeLower\' to coreTraining');
          return WorkoutType.coreTraining;
        } else if (typeLower.contains('flex')) {
           debugPrint('Fallback mapping \'$typeLower\' to flexibility');
          return WorkoutType.flexibility;
        } else if (typeLower.contains('elliptical')) {
           debugPrint('Fallback mapping \'$typeLower\' to elliptical');
          return WorkoutType.elliptical;
        } else if (typeLower.contains('stair')) {
           debugPrint('Fallback mapping \'$typeLower\' to stairClimbing');
          return WorkoutType.stairClimbing;
        } else if (typeLower.contains('row')) {
           debugPrint('Fallback mapping \'$typeLower\' to rowing');
          return WorkoutType.rowing;
        } else {
          // Final fallback if no specific case or keyword matched
          debugPrint('Unknown workout type: $appleWorkoutType (normalized: $typeLower), defaulting to other');
          return WorkoutType.other;
        }
       --- End Original Fallback Logic --- */
    }
  }

  /// Static method to map Apple Health workout type string to the API string format
  static String mapAppleWorkoutTypeToString(String? appleWorkoutType) {
    if (appleWorkoutType == null) return 'Other'; // Default API string

    // Use the existing enum mapping logic first
    final mappedEnum = _mapAppleWorkoutType(appleWorkoutType);
    
    // Convert the mapped enum back to the desired API string format
    switch (mappedEnum) {
      case WorkoutType.running: return 'Running';
      case WorkoutType.walking: return 'Walking';
      case WorkoutType.cycling: return 'Cycling';
      case WorkoutType.swimming: return 'Swimming';
      case WorkoutType.hiking: return 'Hiking';
      case WorkoutType.yoga: return 'Yoga';
      // Map both Strength types to the same API string for simplicity now, 
      // backend preserves original via original_type anyway
      case WorkoutType.strengthTraining:
      case WorkoutType.traditionalStrengthTraining: 
        return 'Strength Training'; 
      case WorkoutType.highIntensityIntervalTraining: return 'HIIT';
      case WorkoutType.pilates: return 'Pilates';
      case WorkoutType.dance: return 'Dance';
      case WorkoutType.functionalTraining: return 'Functional Training';
      case WorkoutType.coreTraining: return 'Core Training';
      case WorkoutType.flexibility: return 'Flexibility';
      case WorkoutType.elliptical: return 'Elliptical';
      case WorkoutType.stairClimbing: return 'Stair Climbing';
      case WorkoutType.rowing: return 'Rowing';
      case WorkoutType.other: return 'Other';
      // No default needed as all enum values are covered
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
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
}
