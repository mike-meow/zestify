import 'package:flutter/material.dart';
import 'package:health_ai/services/api_service_v2.dart';

/// Screen for configuring server settings
class ServerSettingsScreenV2 extends StatefulWidget {
  const ServerSettingsScreenV2({super.key});

  @override
  State<ServerSettingsScreenV2> createState() => _ServerSettingsScreenV2State();
}

class _ServerSettingsScreenV2State extends State<ServerSettingsScreenV2> {
  final _apiService = ApiServiceV2();
  final _serverUrlController = TextEditingController(
    text: 'http://192.168.0.114:8005',
  );

  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  /// Load server URL from preferences
  Future<void> _loadServerUrl() async {
    await _apiService.initialize();

    if (_apiService.baseUrl != null) {
      _serverUrlController.text = _apiService.baseUrl!;
    }
  }

  /// Save server URL
  Future<void> _saveServerUrl() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving server URL...';
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
          _statusMessage =
              isHealthy
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
        _statusMessage = 'Error: $e';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure Server',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.0.114:8006',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveServerUrl,
              child: const Text('Save and Test Connection'),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green : Colors.red,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Current Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Server URL: ${_apiService.baseUrl ?? 'Not set'}'),
            Text('User ID: ${_apiService.userId ?? 'Not set'}'),
          ],
        ),
      ),
    );
  }
}
