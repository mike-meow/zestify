import 'package:flutter/material.dart';
import 'package:health_ai/services/api_service_v2.dart';
import 'package:health_ai/services/health_service_v2.dart';
import 'package:health_ai/theme/app_theme.dart';

/// A simplified screen for health data synchronization
class SimplifiedHealthSyncScreen extends StatefulWidget {
  const SimplifiedHealthSyncScreen({super.key});

  @override
  State<SimplifiedHealthSyncScreen> createState() => _SimplifiedHealthSyncScreenState();
}

class _SimplifiedHealthSyncScreenState extends State<SimplifiedHealthSyncScreen> {
  final _healthService = HealthServiceV2();
  final _apiService = ApiServiceV2();

  bool _isLoading = false;
  String _statusMessage = '';
  
  // Date range selection with default values
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing...';
    });
    
    try {
      await _apiService.initialize();
      await _healthService.initialize();
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready to sync health data';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error initializing: $e';
      });
    }
  }

  /// Download and upload health data
  Future<void> _syncHealthData() async {
    // Check if API service is initialized
    if (!_apiService.isInitialized) {
      setState(() {
        _statusMessage = 'Server not configured. Please enter server details.';
      });
      return;
    }

    // Check if user ID is available
    if (_apiService.userId == null || _apiService.userId!.isEmpty) {
      setState(() {
        _statusMessage = 'User ID not set. Please enter a user ID.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Syncing health data...';
    });

    try {
      final success = await _healthService.fetchAndUploadHealthData(
        startDate: _startDate,
        endDate: _endDate,
        includeWorkoutDetails: true,
      );

      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? 'Health data synced successfully!'
            : 'Failed to sync health data';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  /// Show date picker
  Future<void> _selectDate(bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Server settings
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: TextEditingController(text: _apiService.baseUrl ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Server URL',
                          border: OutlineInputBorder(),
                          hintText: 'http://localhost:8000',
                        ),
                        onChanged: (value) async {
                          await _apiService.initialize(serverUrl: value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: TextEditingController(text: _apiService.userId ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'User ID',
                          border: OutlineInputBorder(),
                          hintText: 'user123',
                        ),
                        onChanged: (value) async {
                          await _apiService.setUserId(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Date range selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date Range',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(true),
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
                              onTap: () => _selectDate(false),
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
              
              // Status and sync button
              if (_isLoading) 
                const LinearProgressIndicator(),
              
              const SizedBox(height: 16),
              
              Text(
                _statusMessage,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _statusMessage.contains('Error') || _statusMessage.contains('Failed')
                      ? Colors.red
                      : _statusMessage.contains('success')
                          ? Colors.green
                          : Colors.black,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Sync button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: Text(
                    _isLoading ? 'Syncing...' : 'Sync Health Data',
                    style: const TextStyle(fontSize: 18),
                  ),
                  onPressed: _isLoading ? null : _syncHealthData,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Back to home button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.home),
                  label: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 18),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
