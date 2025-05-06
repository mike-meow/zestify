import '../base_model.dart';
import 'workout.dart';

/// Represents a collection of workouts (workout history)
class WorkoutHistory extends BaseModel {
  /// List of workouts
  final List<Workout> workouts;

  /// User ID associated with this workout history
  final String userId;

  /// Last sync timestamp
  final DateTime lastSyncTime;

  WorkoutHistory({
    required this.workouts,
    required this.userId,
    required this.lastSyncTime,
  });

  /// Create a WorkoutHistory from a JSON map
  factory WorkoutHistory.fromJson(Map<String, dynamic> json) {
    return WorkoutHistory(
      workouts: List<Workout>.from(
        json['workouts'].map((x) => Workout.fromJson(x)),
      ),
      userId: json['userId'],
      lastSyncTime: DateTime.parse(json['lastSyncTime']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'workouts': workouts.map((x) => x.toJson()).toList(),
      'userId': userId,
      'lastSyncTime': lastSyncTime.toIso8601String(),
    };
  }

  /// Get workouts for a specific date range
  List<Workout> getWorkoutsInDateRange(DateTime start, DateTime end) {
    return workouts.where((workout) {
      return workout.startTime.isAfter(start) &&
          workout.startTime.isBefore(end);
    }).toList();
  }

  /// Get workouts of a specific type
  List<Workout> getWorkoutsByType(String type) {
    return workouts
        .where(
          (workout) =>
              workout.workoutType.toLowerCase().contains(type.toLowerCase()),
        )
        .toList();
  }

  /// Add a new workout to the history
  WorkoutHistory addWorkout(Workout workout) {
    final updatedWorkouts = List<Workout>.from(workouts)..add(workout);
    return WorkoutHistory(
      workouts: updatedWorkouts,
      userId: userId,
      lastSyncTime: DateTime.now(),
    );
  }

  /// Remove a workout from the history
  WorkoutHistory removeWorkout(String workoutId) {
    final updatedWorkouts = workouts.where((w) => w.id != workoutId).toList();
    return WorkoutHistory(
      workouts: updatedWorkouts,
      userId: userId,
      lastSyncTime: DateTime.now(),
    );
  }

  /// Update a workout in the history
  WorkoutHistory updateWorkout(Workout updatedWorkout) {
    final updatedWorkouts =
        workouts.map((workout) {
          return workout.id == updatedWorkout.id ? updatedWorkout : workout;
        }).toList();

    return WorkoutHistory(
      workouts: updatedWorkouts,
      userId: userId,
      lastSyncTime: DateTime.now(),
    );
  }

  /// Get total calories burned across all workouts
  double get totalCaloriesBurned {
    return workouts.fold(0, (sum, workout) => sum + workout.energyBurned);
  }

  /// Get total distance covered across all workouts (in meters)
  double get totalDistance {
    return workouts.fold(0, (sum, workout) => sum + (workout.distance ?? 0));
  }

  /// Get total workout duration (in seconds)
  int get totalDuration {
    return workouts.fold(0, (sum, workout) => sum + workout.durationInSeconds);
  }

  /// Get the most common workout type
  String? get mostCommonWorkoutType {
    if (workouts.isEmpty) return null;

    final typeCounts = <String, int>{};
    for (final workout in workouts) {
      typeCounts[workout.workoutType] =
          (typeCounts[workout.workoutType] ?? 0) + 1;
    }

    String mostCommon = workouts.first.workoutType;
    int highestCount = 0;

    typeCounts.forEach((type, count) {
      if (count > highestCount) {
        highestCount = count;
        mostCommon = type;
      }
    });

    return mostCommon;
  }

  /// Get workouts grouped by month
  Map<String, List<Workout>> get workoutsByMonth {
    final result = <String, List<Workout>>{};

    for (final workout in workouts) {
      final monthKey =
          '${workout.startTime.year}-${workout.startTime.month.toString().padLeft(2, '0')}';
      if (!result.containsKey(monthKey)) {
        result[monthKey] = [];
      }
      result[monthKey]!.add(workout);
    }

    return result;
  }

  /// Get workouts grouped by type
  Map<String, List<Workout>> get workoutsByType {
    final result = <String, List<Workout>>{};

    for (final workout in workouts) {
      if (!result.containsKey(workout.workoutType)) {
        result[workout.workoutType] = [];
      }
      result[workout.workoutType]!.add(workout);
    }

    return result;
  }
}
