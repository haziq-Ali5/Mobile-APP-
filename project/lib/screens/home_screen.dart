import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project/providers/job_provider.dart';
import 'package:project/services/storage_service.dart';
import 'package:project/screens/job_history_screen.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final ScrollController _scrollController = ScrollController();
  List<Uint8List> _selectedImageBytesList = [];
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      List<Uint8List> bytesList = [];
      for (var file in pickedFiles) {
        final bytes = await file.readAsBytes();
        bytesList.add(bytes);
      }
      setState(() {
        _selectedImageBytesList = bytesList;
      });
    }
  }

  Future<void> _submitImages() async {
    if (_selectedImageBytesList.isEmpty) return;

    setState(() => _isLoading = true);
    debugPrint('Starting upload of ${_selectedImageBytesList.length} images');

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Authentication required');

      final jobProvider = Provider.of<JobProvider>(context, listen: false);

      for (var bytes in _selectedImageBytesList) {
        debugPrint('Image size: ${bytes.lengthInBytes} bytes');
      }

      // 1) Upload all selected images at once
      final jobIds = await jobProvider
          .uploadFiles(_selectedImageBytesList)
          .timeout(const Duration(seconds: 200), onTimeout: () {
        throw TimeoutException('Upload timed out');
      });

      debugPrint('Job IDs returned: $jobIds');

      if (mounted) {
        // 2) Clear the selected‐images UI
        setState(() => _selectedImageBytesList = []);

        // 3) Show a SnackBar letting them know “Job submitted”
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job submitted! Tap “History” to track progress.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload timed out. Check your connection.')),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Image Enhanceing App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Job History',
            onPressed: () {
              // Navigate to Job History screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const JobHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // your logout logic …
            },
          ),
        ],
      ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Center(
                child: _selectedImageBytesList.isEmpty
                    ? const Text('No images selected')
                    : Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: _selectedImageBytesList
                            .map(_buildImageBox)
                            .toList(),
                      ),
              ),
              const SizedBox(height: 20),
              if (_selectedImageBytesList.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit for Enhancement'),
                  onPressed: _isLoading ? null : _submitImages,
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Pick Images'),
                onPressed: _pickImages,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageBox(Uint8List imageBytes) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: 150,
          height: 150,
        ),
      ),
    );
  }
}
