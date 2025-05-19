import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project/services/storage_service.dart';
import 'package:project/providers/job_provider.dart';
import 'package:provider/provider.dart';
import 'package:project/providers/auth_provider.dart';
import 'package:project/screens/result_screen.dart';

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

    Future<String> timeoutFuture = Future.delayed(const Duration(seconds: 30), () {
  throw TimeoutException('Upload timed out');
});

final jobIds = await jobProvider.uploadFiles(_selectedImageBytesList)
    .timeout(const Duration(seconds: 15), onTimeout: () {
  throw TimeoutException('Upload timed out');
});

    if (mounted) {
      setState(() => _selectedImageBytesList = []);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Images submitted successfully!')),
      );

      /// ✅ Navigate to ResultScreen(jobId)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(jobId: jobIds.first),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Enhancer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
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
                            .map((imageBytes) => _buildImageBox(imageBytes))
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
                label: const Text('Upload Images'),
                onPressed: _pickImages,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
