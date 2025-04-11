import 'package:flutter/material.dart';
import '../../services/health_service.dart';
import '../../theme/app_theme.dart';

/// A screen for downloading all health data
class HealthDataDownloadScreen extends StatefulWidget {
  const HealthDataDownloadScreen({super.key});

  @override
  State<HealthDataDownloadScreen> createState() =>
      _HealthDataDownloadScreenState();
}

class _HealthDataDownloadScreenState extends State<HealthDataDownloadScreen> {
  final HealthService _healthService = HealthService();
  bool _isLoading = false;
  Map<String, int> _results = {};
  String _statusMessage = '';

  // Default to 5 years ago for maximum historical data
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeWorkoutDetails = true;

  @override
  void initState() {
    super.initState();
    // Set default date range to last 5 years
    final now = DateTime.now();
    _startDate = now.subtract(const Duration(days: 365 * 5));
    _endDate = now;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Health Data'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Information card
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Complete Health Data Download',
                          style: AppTheme.subheadingStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will download ALL your health data from Apple Health and save it to files on your device. '
                      'The data will be organized by category and can be viewed in the File Explorer.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'By default, we download data from the last 5 years to ensure you have your complete health history.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),

            // Date range selection
            Text('Date Range', style: AppTheme.headingStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _selectStartDate,
                    child: Text(
                      _startDate != null
                          ? 'From: ${_formatDate(_startDate!)}'
                          : 'Select Start Date',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _selectEndDate,
                    child: Text(
                      _endDate != null
                          ? 'To: ${_formatDate(_endDate!)}'
                          : 'Select End Date',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Include workout details option
            CheckboxListTile(
              title: const Text('Include Workout Details'),
              subtitle: const Text('Heart rate and route data for workouts'),
              value: _includeWorkoutDetails,
              onChanged:
                  _isLoading
                      ? null
                      : (value) {
                        setState(() {
                          _includeWorkoutDetails = value ?? true;
                        });
                      },
            ),
            const SizedBox(height: 16),

            // Download button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _downloadHealthData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Downloading...'),
                          ],
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.cloud_download),
                            SizedBox(width: 8),
                            Text(
                              'DOWNLOAD ALL HEALTH DATA',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 16),

            // Status message
            if (_statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withAlpha(
                      76,
                    ), // 0.3 * 255 = 76
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_statusMessage),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Results
            if (_results.isNotEmpty) ...[
              Text('Results', style: AppTheme.headingStyle),
              const SizedBox(height: 8),
              Expanded(child: _buildResultsList()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.subtract(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 365 * 10)),
      lastDate: now,
    );

    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 10)),
      lastDate: now,
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadHealthData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing health service...';
      _results = {};
    });

    try {
      // Initialize health service
      final hasPermissions = await _healthService.initialize();
      if (!hasPermissions) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: Health data permissions not granted.';
        });
        return;
      }

      // Download all health data
      setState(() {
        _statusMessage = 'Fetching health data (this may take a while)...';
      });

      final results = await _healthService.fetchAllHealthData(
        startDate: _startDate,
        endDate: _endDate,
        includeWorkoutDetails: _includeWorkoutDetails,
      );

      setState(() {
        _isLoading = false;
        _results = results;
        _statusMessage = 'Download complete! Data saved to device storage.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Widget _buildResultsList() {
    // Group results by category
    final categories = {
      'Activity': [
        'STEPS',
        'WORKOUT',
        'ACTIVE_ENERGY_BURNED',
        'BASAL_ENERGY_BURNED',
        'DISTANCE_WALKING_RUNNING',
        'FLIGHTS_CLIMBED',
        'MOVE_MINUTES',
        'EXERCISE_TIME',
      ],
      'Heart': [
        'HEART_RATE',
        'RESTING_HEART_RATE',
        'HEART_RATE_VARIABILITY_SDNN',
        'HIGH_HEART_RATE_EVENT',
        'LOW_HEART_RATE_EVENT',
        'IRREGULAR_HEART_RATE_EVENT',
        'HEART_RATE_FOR_WORKOUTS',
      ],
      'Body': [
        'HEIGHT',
        'WEIGHT',
        'BODY_MASS_INDEX',
        'BODY_FAT_PERCENTAGE',
        'WAIST_CIRCUMFERENCE',
      ],
      'Health Metrics': [
        'BLOOD_GLUCOSE',
        'BLOOD_OXYGEN',
        'BLOOD_PRESSURE_DIASTOLIC',
        'BLOOD_PRESSURE_SYSTOLIC',
        'BODY_TEMPERATURE',
        'RESPIRATORY_RATE',
        'ELECTRODERMAL_ACTIVITY',
        'WATER',
        'MINDFULNESS',
      ],
      'Nutrition': ['DIETARY_ENERGY_CONSUMED'],
      'Sleep': [
        'SLEEP_ASLEEP',
        'SLEEP_AWAKE',
        'SLEEP_IN_BED',
        'SLEEP_DEEP',
        'SLEEP_REM',
        'SLEEP_LIGHT',
        'SLEEP_SESSION',
      ],
      'Other': ['ROUTE_DATA_FOR_WORKOUTS'],
    };

    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories.keys.elementAt(index);
        final types = categories[category]!;

        // Check if any data exists for this category
        final hasData = types.any((type) {
          final count = _results[type];
          return count != null && count > 0;
        });

        if (!hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('No data available'),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children:
                types.map((type) {
                  final count = _results[type];
                  if (count == null || count <= 0) {
                    return const SizedBox.shrink();
                  }

                  return ListTile(
                    title: Text(type),
                    trailing: Text(
                      '$count records',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
