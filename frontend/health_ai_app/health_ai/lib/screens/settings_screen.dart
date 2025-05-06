import 'package:flutter/material.dart';
import 'package:health_ai/services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  bool _isLoading = true;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    await _apiService.initialize();

    setState(() {
      _serverUrlController.text = _apiService.baseUrl ?? '';
      _userIdController.text = _apiService.userId ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Saving settings...';
    });

    try {
      // Save server URL if changed
      final serverUrl = _serverUrlController.text.trim();
      if (serverUrl != _apiService.baseUrl) {
        await _apiService.initialize(serverUrl: serverUrl);
      }

      // Save user ID if changed
      final userId = _userIdController.text.trim();
      if (userId != _apiService.userId) {
        await _apiService.setUserId(userId);
      }

      setState(() {
        _statusMessage = 'Settings saved successfully!';
      });

      // Check server health
      final isServerReachable = await _apiService.checkServerHealth();

      setState(() {
        _statusMessage =
            isServerReachable
                ? 'Server connection successful!'
                : 'Warning: Could not connect to server. Please check the URL.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error saving settings: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'e.g., http://192.168.1.100:8000',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        hintText: 'Your unique user identifier',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Save Settings',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color:
                              _statusMessage.contains('Error')
                                  ? Colors.red
                                  : _statusMessage.contains('Warning')
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Health Data',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Sync Health Data'),
                      subtitle: const Text(
                        'Fetch and upload health data with custom time range',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, '/health_data_download');
                      },
                    ),
                  ],
                ),
      ),
    );
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _userIdController.dispose();
    super.dispose();
  }
}
