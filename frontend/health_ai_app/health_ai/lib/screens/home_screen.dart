import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/health_orb.dart';
import '../widgets/bubble_card.dart';
import '../widgets/chat_box.dart';
import 'workout_history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with health orb - more compact
            Container(
              padding: const EdgeInsets.only(top: 16, bottom: 10),
              child: Column(
                children: [
                  const Text(
                    'Your Health Score',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const HealthOrb(healthScore: 85),
                  const SizedBox(height: 4),
                  Text(
                    'Excellent!',
                    style: AppTheme.subheadingStyle.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Main content with bubbly sections
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          top: 4,
                          bottom: 8,
                        ),
                        child: Text(
                          'Your Wellness Journey',
                          style: AppTheme.subheadingStyle,
                        ),
                      ),

                      // Workout section
                      BubbleCard(
                        title: 'Workout History',
                        subtitle: 'Great progress! 3 workouts this week',
                        icon: Icons.fitness_center,
                        gradient: AppTheme.primaryGradient,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const WorkoutHistoryScreen(),
                            ),
                          );
                        },
                      ),

                      // Dietary section
                      BubbleCard(
                        title: 'Dietary Tracking',
                        subtitle: 'You\'re on a 5-day healthy streak!',
                        icon: Icons.restaurant,
                        gradient: AppTheme.secondaryGradient,
                        onTap: () {
                          // Navigate to dietary tracking
                        },
                      ),

                      // Words of the day
                      BubbleCard(
                        title: 'Words of the Day',
                        subtitle: 'Small steps lead to big changes',
                        icon: Icons.format_quote,
                        gradient: AppTheme.accentGradient,
                        onTap: () {
                          // Show words of the day
                        },
                      ),

                      // Goal of the week
                      BubbleCard(
                        title: 'Goal of the Week',
                        subtitle: 'Complete 4 workouts by Sunday',
                        icon: Icons.flag,
                        gradient: AppTheme.purpleGradient,
                        onTap: () {
                          // Navigate to goals
                        },
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom chat box
            Padding(
              padding: const EdgeInsets.all(16),
              child: ChatBox(
                onTap: () {
                  // Open chat screen
                },
                onVoiceChat: () {
                  // Start voice chat
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
