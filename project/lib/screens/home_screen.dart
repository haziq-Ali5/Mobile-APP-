import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project/services/storage_service.dart';
import 'package:project/providers/job_provider.dart';
import 'package:provider/provider.dart';
import 'package:project/constants/enums.dart';
import 'package:project/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
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
    
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storageService.getToken();
      if (!mounted) return;
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login required to submit images.')),
        );
        return;
      }

      // Get the job provider to handle the API call and WebSocket connection
      final jobProvider = Provider.of<JobProvider>(context, listen: false);
      
      // For each image, submit it and track the job
      for (int i = 0; i < _selectedImageBytesList.length; i++) {
        final imageBytes = _selectedImageBytesList[i];
        await jobProvider.uploadImageBytes(imageBytes);
      }

      if (!mounted) return;
      
      // If we get here, submission was successful for at least the first image
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Images submitted successfully!')),
      );
      
      // If a job ID was created, navigate to the result screen for the latest job
      if (jobProvider.latestJobId != null) {
        Navigator.pushNamed(
          context, 
          '/result', 
          arguments: jobProvider.latestJobId
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildImageBox(Uint8List imageBytes) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          width: 300,
          height: 300,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = Provider.of<JobProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Enhancer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Add logout functionality
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
                        spacing: 16,
                        runSpacing: 16,
                        children: _selectedImageBytesList
                            .map((imageBytes) => _buildImageBox(imageBytes))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 30),
              // Show status indicator when processing
              if (jobProvider.status == JobStatus.processing ||
                  jobProvider.status == JobStatus.uploading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(jobProvider.status == JobStatus.uploading 
                      ? 'Uploading...' 
                      : 'Processing...'),
                  ],
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
              
              // Show recently processed jobs
              if (jobProvider.jobs.isNotEmpty) ...[
                const SizedBox(height: 40),
                const Text(
                  'Recent Jobs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...jobProvider.jobs.map((job) => ListTile(
                  title: Text('Job: ${job.jobId.substring(0, 8)}...'),
                  subtitle: Text('Status: ${job.status.toString().split('.').last}'),
                  trailing: job.status == JobStatus.completed 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : job.status == JobStatus.failed
                          ? const Icon(Icons.error, color: Colors.red)
                          : const CircularProgressIndicator(),
                  onTap: job.status == JobStatus.completed
                      ? () => Navigator.pushNamed(
                          context, 
                          '/result', 
                          arguments: job.jobId
                        )
                      : null,
                )).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}