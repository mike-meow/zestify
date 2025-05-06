import 'package:flutter/material.dart';
import 'package:health_ai/services/health_service.dart';
import 'package:health_ai/services/biometrics_fetcher.dart';
import 'package:health_ai/services/api_service.dart';

class HealthSyncScreen extends StatefulWidget {
  const HealthSyncScreen({Key? key}) : super(key: key);

  @override
  _HealthSyncScreenState createState() => _HealthSyncScreenState();
}

class _HealthSyncScreenState extends State<HealthSyncScreen> {
  final HealthService _healthService = HealthService();
  final BiometricsFetcher _biometricsFetcher = BiometricsFetcher();
  final ApiService _apiService = ApiService();

  bool _isSyncing = false;
  String _syncStatus = 'Select a date range and tap "Sync"';
  double _progress = 0.0;

  // Date range selection
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _apiService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Date Range',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectStartDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _selectEndDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'End Date',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Status and progress
              if (_isSyncing) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 16),
              ],

              Text(
                _syncStatus,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 24),

              // Sync buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync All Health Data'),
                      onPressed: _isSyncing ? null : _startFullSync,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.scale),
                      label: const Text('Sync Weight Only'),
                      onPressed: _isSyncing ? null : _syncWeightOnly,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Go to home button
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.home),
                      label: const Text('Go to Home Screen'),
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    if (_isSyncing) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2010),
      lastDate: _endDate,
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_isSyncing) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _startFullSync() async {
    if (!await _checkInitialized()) return;

    setState(() {
      _isSyncing = true;
      _progress = 0.0;
      _syncStatus = 'Initializing health data sync...';
    });

    try {
      setState(() {
        _syncStatus =
            'Fetching health data from ${_startDate.year}-${_startDate.month}-${_startDate.day} to ${_endDate.year}-${_endDate.month}-${_endDate.day}...';
        _progress = 0.2;
      });

      // Start the data fetch and upload
      final success = await _healthService.fetchAndUploadHealthData(
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _progress = 1.0;
        _syncStatus =
            success
                ? 'Health data sync completed successfully!'
                : 'Error syncing health data. Please try again.';
      });
    } catch (e) {
      setState(() {
        _progress = 0.0;
        _syncStatus = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncWeightOnly() async {
    if (!await _checkInitialized()) return;

    setState(() {
      _isSyncing = true;
      _progress = 0.0;
      _syncStatus = 'Fetching weight data only...';
    });

    try {
      setState(() {
        _syncStatus =
            'Fetching weight data from ${_startDate.year}-${_startDate.month}-${_startDate.day} to ${_endDate.year}-${_endDate.month}-${_endDate.day}...';
        _progress = 0.3;
      });

      // Direct upload of weight data only
      final success = await _biometricsFetcher.directUploadWeightHistory(
        _apiService.userId ?? '',
        _apiService.baseUrl ?? '',
        _startDate,
        _endDate,
      );

      setState(() {
        _progress = 1.0;
        _syncStatus =
            success
                ? 'Weight data uploaded successfully!'
                : 'Error uploading weight data. Check logs for details.';
      });
    } catch (e) {
      setState(() {
        _progress = 0.0;
        _syncStatus = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  /// Check if API service is initialized
  Future<bool> _checkInitialized() async {
    if (!_apiService.isInitialized || _apiService.userId == null) {
      setState(() {
        _syncStatus = 'API not configured. Please check settings.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure the API settings first.'),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }

    return true;
  }
}
