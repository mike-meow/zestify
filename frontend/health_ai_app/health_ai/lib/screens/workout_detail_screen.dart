import 'package:flutter/material.dart';
import '../models/workout/workout.dart';
import '../models/workout/heart_rate_sample.dart';
import '../services/health_service.dart';
import '../theme/app_theme.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final String workoutId;

  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Future<Workout?> _workoutFuture;
  late Future<List<HeartRateSample>> _heartRateDataFuture;
  late Future<List<Map<String, dynamic>>> _routeDataFuture;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  void _loadWorkout() {
    final healthService = HealthService();
    _workoutFuture = healthService.fetchWorkoutById(widget.workoutId);
    _workoutFuture.then((workout) {
      if (workout != null) {
        // Load heart rate data
        _heartRateDataFuture = healthService.getHeartRateDataForWorkout(
          workout,
        );

        // Load route data
        _routeDataFuture = healthService.getRouteDataForWorkout(workout);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FutureBuilder<Workout?>(
        future: _workoutFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading workout',
                    style: AppTheme.subheadingStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTheme.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadWorkout();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final workout = snapshot.data;

          if (workout == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: AppTheme.primaryColor.withOpacity(0.5),
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  Text('Workout not found', style: AppTheme.subheadingStyle),
                  const SizedBox(height: 8),
                  Text(
                    'The workout you\'re looking for doesn\'t exist',
                    style: AppTheme.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(workout),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWorkoutSummary(workout),
                      const SizedBox(height: 24),
                      _buildWorkoutMetrics(workout),
                      const SizedBox(height: 24),
                      _buildHeartRateSection(workout),
                      const SizedBox(height: 24),
                      _buildRouteSection(workout),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(Workout workout) {
    // Determine color based on workout type
    Color color;
    switch (workout.type) {
      case WorkoutType.running:
      case WorkoutType.walking:
      case WorkoutType.hiking:
        color = AppTheme.primaryColor;
        break;
      case WorkoutType.cycling:
      case WorkoutType.swimming:
      case WorkoutType.rowing:
      case WorkoutType.elliptical:
      case WorkoutType.stairClimbing:
        color = AppTheme.secondaryColor;
        break;
      case WorkoutType.yoga:
      case WorkoutType.pilates:
      case WorkoutType.flexibility:
        color = AppTheme.accentColor;
        break;
      default:
        color = const Color(0xFF7B1FA2); // Purple
    }

    // Format date
    final date = workout.startTime;
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: color,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          workout.type.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 20,
                bottom: 60,
                child: Icon(
                  Icons.fitness_center,
                  color: Colors.white.withOpacity(0.2),
                  size: 100,
                ),
              ),
              Positioned(
                left: 20,
                bottom: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workout.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutSummary(Workout workout) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: AppTheme.subheadingStyle),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  Icons.timer,
                  'Duration',
                  workout.formattedDuration,
                  AppTheme.primaryColor,
                ),
                _buildSummaryItem(
                  Icons.local_fire_department,
                  'Calories',
                  workout.formattedCalories,
                  AppTheme.accentColor,
                ),
                _buildSummaryItem(
                  Icons.straighten,
                  'Distance',
                  workout.formattedDistance,
                  AppTheme.secondaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTheme.captionStyle),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildWorkoutMetrics(Workout workout) {
    // Format start and end times
    final startTime =
        '${workout.startTime.hour.toString().padLeft(2, '0')}:${workout.startTime.minute.toString().padLeft(2, '0')}';
    final endTime =
        '${workout.endTime.hour.toString().padLeft(2, '0')}:${workout.endTime.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Details', style: AppTheme.subheadingStyle),
            const SizedBox(height: 16),
            _buildDetailRow('Start Time', startTime),
            const Divider(),
            _buildDetailRow('End Time', endTime),
            const Divider(),
            _buildDetailRow('Source', workout.source),
            if (workout.averageHeartRate != null) ...[
              const Divider(),
              _buildDetailRow(
                'Avg. Heart Rate',
                '${workout.averageHeartRate!.round()} bpm',
              ),
            ],
            if (workout.metadata != null && workout.metadata!.isNotEmpty) ...[
              const Divider(),
              _buildDetailRow(
                'Device',
                workout.metadata!['device'] ?? 'Unknown',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.captionStyle),
          Text(
            value,
            style: AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTheme.captionStyle),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.bold,
            color:
                label == 'Max'
                    ? Colors.red
                    : label == 'Min'
                    ? Colors.blue
                    : AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateSection(Workout workout) {
    if (workout.averageHeartRate == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heart Rate', style: AppTheme.subheadingStyle),
            const SizedBox(height: 16),
            FutureBuilder<List<HeartRateSample>>(
              future: _heartRateDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(
                      'No heart rate data available',
                      style: AppTheme.captionStyle,
                    ),
                  );
                }

                // Get heart rate statistics
                final samples = snapshot.data!;
                final healthService = HealthService();
                final stats = healthService.calculateHeartRateStats(samples);

                // Heart rate chart would go here
                return Column(
                  children: [
                    // Heart rate stats
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHeartRateStat(
                            'Min',
                            '${stats['min']?.round() ?? 'N/A'} bpm',
                          ),
                          _buildHeartRateStat(
                            'Avg',
                            '${stats['avg']?.round() ?? 'N/A'} bpm',
                          ),
                          _buildHeartRateStat(
                            'Max',
                            '${stats['max']?.round() ?? 'N/A'} bpm',
                          ),
                        ],
                      ),
                    ),
                    // Heart rate chart
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Heart rate chart will be displayed here',
                          style: AppTheme.captionStyle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSection(Workout workout) {
    // Only show route section for outdoor workouts with distance
    if (workout.distance == null || workout.distance == 0) {
      return const SizedBox.shrink();
    }

    // Check if this is an outdoor workout type
    final isOutdoorWorkout = [
      WorkoutType.running,
      WorkoutType.walking,
      WorkoutType.hiking,
      WorkoutType.cycling,
    ].contains(workout.type);

    if (!isOutdoorWorkout) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route', style: AppTheme.subheadingStyle),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _routeDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(
                      'No route data available',
                      style: AppTheme.captionStyle,
                    ),
                  );
                }

                // Get route statistics
                final routePoints = snapshot.data!;

                // Calculate elevation gain/loss
                double? elevationGain;
                double? elevationLoss;

                if (routePoints.every((point) => point['altitude'] != null)) {
                  elevationGain = 0;
                  elevationLoss = 0;

                  for (int i = 1; i < routePoints.length; i++) {
                    final prevAltitude =
                        routePoints[i - 1]['altitude'] as double;
                    final currAltitude = routePoints[i]['altitude'] as double;
                    final diff = currAltitude - prevAltitude;

                    if (diff > 0) {
                      elevationGain = elevationGain! + diff;
                    } else if (diff < 0) {
                      elevationLoss = elevationLoss! + diff.abs();
                    }
                  }
                }

                // Route map would go here
                return Column(
                  children: [
                    // Route stats
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRouteStat(
                            'Distance',
                            workout.formattedDistance,
                          ),
                          if (elevationGain != null)
                            _buildRouteStat(
                              'Elevation Gain',
                              '${elevationGain.round()} m',
                            ),
                          if (elevationLoss != null)
                            _buildRouteStat(
                              'Elevation Loss',
                              '${elevationLoss.round()} m',
                            ),
                        ],
                      ),
                    ),
                    // Route map
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Route map will be displayed here',
                              style: AppTheme.captionStyle,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${routePoints.length} GPS points recorded',
                              style: AppTheme.captionStyle.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTheme.captionStyle),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.bold,
            color:
                label.contains('Gain')
                    ? Colors.green
                    : label.contains('Loss')
                    ? Colors.red
                    : AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}
