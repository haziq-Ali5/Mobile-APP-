import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:project/services/api_service.dart';
import 'package:project/models/job.dart';
import 'package:project/constants/enums.dart';
import 'package:project/services/database_helper.dart';

class ResultScreen extends StatefulWidget {
  final String jobId;
  const ResultScreen({super.key, required this.jobId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<Uint8List> _enhancedImages = [];
  List<ProcessingJob> _userJobs = [];
  bool _isLoading = true;
  String? _errorMessage;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _fetchEnhancedImages();
    _loadPreviousJobs();
  }

  // Load user's previous enhanced images from the database
  Future<void> _loadPreviousJobs() async {
    try {
      final jobs = await _databaseHelper.getAllJobs();
      setState(() {
        _userJobs = jobs.where((job) => 
          job.status == JobStatus.completed && 
          job.jobId != widget.jobId
        ).toList();
      });
    } catch (e) {
      debugPrint('Error loading previous jobs: $e');
    }
  }

  Future<void> _fetchEnhancedImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // First check if we already have the image stored locally
      final savedJob = await _getSavedJob(widget.jobId);
      if (savedJob != null && savedJob.resultImage != null) {
    setState(() {
      _enhancedImages = [savedJob.resultImage!];
      _isLoading = false;
    });
    return;
  }
      
      // Try batch endpoint first
      try {
        final images = await apiService.getEnhancedImages(widget.jobId);
        if (images.isNotEmpty) {
          // Save images locally for future use
          for (var image in images) {
            await _databaseHelper.saveEnhancedImageLocally(widget.jobId, image);
          }
          
          setState(() {
            _enhancedImages = images;
            _isLoading = false;
          });
          return;
        }
      } catch (batchError) {
        debugPrint('Batch endpoint failed: $batchError');
      }
      
      // Fallback to single image
      try {
        final singleImage = await apiService.getEnhancedImage(widget.jobId);
        // Save image locally
        await _databaseHelper.saveEnhancedImageLocally(widget.jobId, singleImage);
        
        setState(() {
          _enhancedImages = [singleImage];
          _isLoading = false;
        });
      } catch (singleError) {
        debugPrint('Single image failed: $singleError');
        throw Exception('No enhanced images found');
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load results: ${e.toString()}';
        _isLoading = false;
      });
      debugPrint('Error fetching enhanced images: $e');
    }
  }

  Future<ProcessingJob?> _getSavedJob(String jobId) async {
    try {
      final jobs = await _databaseHelper.getAllJobs();
      return jobs.firstWhere((job) => job.jobId == jobId);
    } catch (e) {
      debugPrint('Error getting saved job: $e');
      return null;
    }
  }

  Future<void> _saveImage(Uint8List imageBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(imageBytes);

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) throw Exception('Storage permission not granted');
      }

      final result = await GallerySaver.saveImage(tempPath);
      if (result != true) throw Exception('Failed to save image');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    }
  }

  Future<void> _shareImage(Uint8List imageBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(tempPath)],
        text: 'Enhanced image from Image Enhancement App',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing image: $e')),
        );
      }
    }
  }

  void _showFullScreenImage(Uint8List imageBytes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(imageBytes),
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> _loadPreviousImage(ProcessingJob job) async {
    try {
      if (job.resultImage != null) {
      return job.resultImage;
    }
      if (job.localImagePath != null && !kIsWeb) {
        final file = File(job.localImagePath!);
        if (await file.exists()) {
          return file.readAsBytesSync();
        }
      }
      
      // If not available locally, try to fetch from API
      final apiService = Provider.of<ApiService>(context, listen: false);
      return await apiService.getEnhancedImage(job.jobId);
    } catch (e) {
      debugPrint('Error loading previous image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Images'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
            ? Center(child: Text('Error: $_errorMessage'))
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_enhancedImages.isNotEmpty) ...[
                        Text(
                          'Current Processed Image:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _enhancedImages
                                .map((image) => _buildImageCard(image))
                                .toList(),
                          ),
                        ),
                        const Divider(height: 32),
                      ] else if (!_isLoading && _enhancedImages.isEmpty) ...[
                        const Center(child: Text('No enhanced images found for this job.')),
                        const SizedBox(height: 16),
                      ],
                      
                      if (_userJobs.isNotEmpty) ...[
                        Text(
                          'Your Previous Enhanced Images:',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _buildPreviousImagesGrid(),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPreviousImagesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _userJobs.length,
      itemBuilder: (context, index) {
        final job = _userJobs[index];
        return FutureBuilder<Uint8List?>(
          future: _loadPreviousImage(job),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
  return Card(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text('Loading...', 
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}
            
            return _buildImageCard(snapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildImageCard(Uint8List imageBytes) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showFullScreenImage(imageBytes),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: () => _saveImage(imageBytes),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: () => _shareImage(imageBytes),
              ),
            ],
          )
        ],
      ),
    );
  }
}