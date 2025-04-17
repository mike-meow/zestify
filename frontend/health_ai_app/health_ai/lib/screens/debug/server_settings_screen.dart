import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// A screen for configuring the server settings
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _serverUrlController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading settings...';
    });

    try {
      await _apiService.initialize();
      
      setState(() {
        _serverUrlController.text = _apiService.baseUrl ?? '';
        _isLoading = false;
        _statusMessage = _apiService.isInitialized
            ? 'Server URL loaded from preferences'
            : 'No server URL configured';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading settings: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving settings...';
      _isSuccess = false;
    });

    try {
      final serverUrl = _serverUrlController.text.trim();
      
      if (serverUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Server URL cannot be empty';
          _isSuccess = false;
        });
        return;
      }

      // Initialize API service with new URL
      final success = await _apiService.initialize(serverUrl: serverUrl);
      
      if (success) {
        // Test connection
        final isHealthy = await _apiService.checkServerHealth();
        
        setState(() {
          _isLoading = false;
          _statusMessage = isHealthy
              ? 'Server URL saved and connection successful'
              : 'Server URL saved but connection failed';
          _isSuccess = isHealthy;
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to save server URL';
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error saving settings: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _createUser() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating user...';
      _isSuccess = false;
    });

    try {
      final userId = await _apiService.createUser();
      
      setState(() {
        _isLoading = false;
        _statusMessage = userId != null
            ? 'User created: $userId'
            : 'Failed to create user';
        _isSuccess = userId != null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error creating user: $e';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Settings'),
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
                          'Server Configuration',
                          style: AppTheme.subheadingStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the URL of your local server. This should be the IP address of your computer on the same WiFi network as your phone.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Example: http://192.168.0.114:8000',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),

            // Server URL input
            Text('Server URL', style: AppTheme.headingStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                hintText: 'http://192.168.0.114:8000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.link),
                enabled: !_isLoading,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
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
                          Text('Saving...'),
                        ],
                      )
                    : const Text('SAVE SERVER URL'),
              ),
            ),
            const SizedBox(height: 16),

            // Create user button
            if (_apiService.isInitialized && _apiService.userId == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('CREATE USER'),
                ),
              ),
            
            // User ID display
            if (_apiService.isInitialized && _apiService.userId != null)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'User ID',
                            style: AppTheme.subheadingStyle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _apiService.userId!,
                        style: const TextStyle(fontFamily: 'monospace'),
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
                  color: _isSuccess ? Colors.green[50] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess
                        ? Colors.green
                        : AppTheme.primaryColor.withAlpha(76),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isSuccess ? Colors.green : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_statusMessage),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
