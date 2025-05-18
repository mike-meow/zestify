import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout/workout.dart';
import '../models/workout/workout_history.dart';
import '../services/unified_health_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bubble_card.dart';
import 'workout_detail_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen>
    with SingleTickerProviderStateMixin {
  late Future<WorkoutHistory> _workoutHistoryFuture;
  String? _selectedType;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Initialize with an empty future that will be replaced when the screen is built
    _workoutHistoryFuture = Future.value(
      WorkoutHistory(
        workouts: [],
        userId: 'current_user',
        lastSyncTime: DateTime.now(),
      ),
    );

    // Delay loading health data to avoid startup crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkoutHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadWorkoutHistory() {
    final healthService = UnifiedHealthService();
    _workoutHistoryFuture = healthService.fetchWorkoutHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Workout History',
          style: AppTheme.headingStyle.copyWith(fontSize: 20),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [Tab(text: 'All Workouts'), Tab(text: 'Statistics')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildWorkoutList(), _buildStatisticsTab()],
      ),
    );
  }

  Widget _buildWorkoutList() {
    return FutureBuilder<WorkoutHistory>(
      future: _workoutHistoryFuture,
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
                Text('Error loading workouts', style: AppTheme.subheadingStyle),
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
                      _loadWorkoutHistory();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final workoutHistory = snapshot.data!;

        if (workoutHistory.workouts.isEmpty) {
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
                Text('No workouts found', style: AppTheme.subheadingStyle),
                const SizedBox(height: 8),
                Text(
                  'Start tracking your workouts with Apple Health',
                  style: AppTheme.captionStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loadWorkoutHistory();
                    });
                  },
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        // Filter workouts by type if a type is selected
        final workouts =
            _selectedType != null
                ? workoutHistory.getWorkoutsByType(_selectedType!)
                : workoutHistory.workouts;

        return Column(
          children: [
            _buildTypeFilter(workoutHistory),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  return _buildWorkoutCard(workout);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeFilter(WorkoutHistory history) {
    // Get unique workout types
    final types = history.workoutsByType.keys.toList();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All types filter
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedType == null,
              onSelected: (selected) {
                setState(() {
                  _selectedType = null;
                });
              },
              backgroundColor: AppTheme.backgroundColor,
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color:
                    _selectedType == null
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
              ),
            ),
          ),

          // Type filters
          ...types.map((type) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  Workout(
                    id: '',
                    workoutType: type,
                    startTime: DateTime.now(),
                    endTime: DateTime.now(),
                    durationInSeconds: 0,
                    energyBurned: 0,
                    source: '',
                  ).displayName,
                ),
                selected: _selectedType == type,
                onSelected: (selected) {
                  setState(() {
                    _selectedType = selected ? type : null;
                  });
                },
                backgroundColor: AppTheme.backgroundColor,
                selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color:
                      _selectedType == type
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondaryColor,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Workout workout) {
    // Determine gradient based on workout type
    LinearGradient gradient;
    final typeLower = workout.workoutType.toLowerCase();

    if (typeLower.contains('run') ||
        typeLower.contains('walk') ||
        typeLower.contains('hik')) {
      gradient = AppTheme.primaryGradient;
    } else if (typeLower.contains('cycl') ||
        typeLower.contains('swim') ||
        typeLower.contains('row') ||
        typeLower.contains('elliptical') ||
        typeLower.contains('stair')) {
      gradient = AppTheme.secondaryGradient;
    } else if (typeLower.contains('yoga') ||
        typeLower.contains('pilates') ||
        typeLower.contains('flex')) {
      gradient = AppTheme.accentGradient;
    } else {
      gradient = AppTheme.purpleGradient;
    }

    // Format date
    final date = workout.startTime;
    final formattedDate = '${date.day}/${date.month}/${date.year}';
    final formattedTime =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return BubbleCard(
      title: workout.displayName,
      subtitle:
          '$formattedDate at $formattedTime • ${workout.formattedDuration}',
      icon: Icons.fitness_center,
      gradient: gradient,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutDetailScreen(workoutId: workout.id),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    return FutureBuilder<WorkoutHistory>(
      future: _workoutHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text(
              'Error loading statistics',
              style: AppTheme.subheadingStyle,
            ),
          );
        }

        final workoutHistory = snapshot.data!;

        if (workoutHistory.workouts.isEmpty) {
          return Center(
            child: Text(
              'No workout data available',
              style: AppTheme.subheadingStyle,
            ),
          );
        }

        // Calculate statistics
        final totalWorkouts = workoutHistory.workouts.length;
        final totalCalories = workoutHistory.totalCaloriesBurned.round();
        final totalDistanceKm = (workoutHistory.totalDistance / 1000)
            .toStringAsFixed(1);
        final totalHours = (workoutHistory.totalDuration / 3600)
            .toStringAsFixed(1);
        final mostCommonType =
            workoutHistory.mostCommonWorkoutType != null
                ? Workout(
                  id: '',
                  workoutType: workoutHistory.mostCommonWorkoutType!,
                  startTime: DateTime.now(),
                  endTime: DateTime.now(),
                  durationInSeconds: 0,
                  energyBurned: 0,
                  source: '',
                ).displayName
                : 'None';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Workout Summary', style: AppTheme.subheadingStyle),
              const SizedBox(height: 16),

              // Summary cards
              _buildStatCard(
                'Total Workouts',
                totalWorkouts.toString(),
                Icons.fitness_center,
                AppTheme.primaryGradient,
              ),

              _buildStatCard(
                'Calories Burned',
                '$totalCalories cal',
                Icons.local_fire_department,
                AppTheme.accentGradient,
              ),

              _buildStatCard(
                'Distance Covered',
                '$totalDistanceKm km',
                Icons.straighten,
                AppTheme.secondaryGradient,
              ),

              _buildStatCard(
                'Time Spent',
                '$totalHours hours',
                Icons.timer,
                AppTheme.purpleGradient,
              ),

              _buildStatCard(
                'Favorite Activity',
                mostCommonType,
                Icons.favorite,
                const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFF48FB1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),

              const SizedBox(height: 24),
              Text('Monthly Activity', style: AppTheme.subheadingStyle),
              const SizedBox(height: 16),

              // Monthly activity chart would go here
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Monthly activity chart will be displayed here',
                    style: AppTheme.captionStyle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    LinearGradient gradient,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.captionStyle.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTheme.subheadingStyle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
