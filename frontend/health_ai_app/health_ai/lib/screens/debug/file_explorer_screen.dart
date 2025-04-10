import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/file_storage_service.dart';
import '../../theme/app_theme.dart';

/// A screen for exploring and viewing files saved by the app
class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  final FileStorageService _fileStorage = FileStorageService();
  Map<String, List<String>> _files = {};
  String? _selectedCategory;
  String? _selectedFile;
  String _fileContent = '';
  bool _isLoading = true;
  String _directoryPath = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _fileStorage.getFileList();
      final path = await _fileStorage.getHealthDataDirectoryPath();
      
      setState(() {
        _files = files;
        _directoryPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading files: $e');
    }
  }

  Future<void> _loadFileContent(String category, String fileName) async {
    setState(() {
      _isLoading = true;
      _fileContent = '';
    });

    try {
      String filePath;
      if (category == 'health_data') {
        filePath = '$_directoryPath/$fileName';
      } else if (category == 'workouts') {
        filePath = '$_directoryPath/workouts/$fileName';
      } else if (category == 'heart_rate') {
        filePath = '$_directoryPath/heart_rate/$fileName';
      } else if (category == 'route_data') {
        filePath = '$_directoryPath/route_data/$fileName';
      } else {
        filePath = '$_directoryPath/$fileName';
      }

      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        
        // Try to format JSON
        try {
          final jsonData = jsonDecode(content);
          final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonData);
          setState(() {
            _fileContent = prettyJson;
            _selectedFile = fileName;
            _selectedCategory = category;
          });
        } catch (e) {
          // If not valid JSON, show as is
          setState(() {
            _fileContent = content;
            _selectedFile = fileName;
            _selectedCategory = category;
          });
        }
      } else {
        setState(() {
          _fileContent = 'File not found: $filePath';
          _selectedFile = fileName;
          _selectedCategory = category;
        });
      }
    } catch (e) {
      setState(() {
        _fileContent = 'Error loading file: $e';
      });
      debugPrint('Error loading file content: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _fileContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File content copied to clipboard')),
    );
  }

  Future<void> _shareFilePath() async {
    String filePath;
    if (_selectedCategory == 'health_data') {
      filePath = '$_directoryPath/$_selectedFile';
    } else if (_selectedCategory == 'workouts') {
      filePath = '$_directoryPath/workouts/$_selectedFile';
    } else if (_selectedCategory == 'heart_rate') {
      filePath = '$_directoryPath/heart_rate/$_selectedFile';
    } else if (_selectedCategory == 'route_data') {
      filePath = '$_directoryPath/route_data/$_selectedFile';
    } else {
      filePath = '$_directoryPath/$_selectedFile';
    }
    
    await Clipboard.setData(ClipboardData(text: filePath));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File path copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyToClipboard,
            ),
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareFilePath,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // File categories and list
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Files',
                          style: AppTheme.headingStyle,
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: _files.entries.map((entry) {
                            final category = entry.key;
                            final fileList = entry.value;
                            
                            return ExpansionTile(
                              title: Text(
                                category,
                                style: AppTheme.subheadingStyle,
                              ),
                              initiallyExpanded: category == _selectedCategory,
                              children: fileList.map((fileName) {
                                return ListTile(
                                  title: Text(
                                    fileName,
                                    style: TextStyle(
                                      color: _selectedFile == fileName && _selectedCategory == category
                                          ? AppTheme.primaryColor
                                          : null,
                                      fontWeight: _selectedFile == fileName && _selectedCategory == category
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                  onTap: () => _loadFileContent(category, fileName),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Vertical divider
                const VerticalDivider(width: 1),
                
                // File content
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedFile != null)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            _selectedFile!,
                            style: AppTheme.headingStyle,
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: SelectableText(
                            _fileContent.isEmpty
                                ? 'Select a file to view its content'
                                : _fileContent,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Directory: $_directoryPath',
            style: AppTheme.captionStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
