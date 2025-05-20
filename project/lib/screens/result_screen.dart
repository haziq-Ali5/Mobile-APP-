import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:project/services/api_service.dart';
import 'package:project/services/hive_helper.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class ResultScreen extends StatefulWidget {
  final String jobId;

  const ResultScreen({
    super.key,
    required this.jobId,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<Uint8List> _enhancedImages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchEnhancedImages();
  }

  Future<void> _fetchEnhancedImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Assume you have your HiveHelper and ApiService properly set up
      final hiveHelper = HiveHelper();
      final hiveJob = hiveHelper.getJob(widget.jobId);

      if (hiveJob != null && hiveJob.resultImage != null) {
        setState(() {
          _enhancedImages = [hiveJob.resultImage!];
          _isLoading = false;
        });
        return;
      }

      final apiService = ApiService();
      final image = await apiService.getEnhancedImage(widget.jobId);

      setState(() {
        _enhancedImages = [image];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load image: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveImage(Uint8List imageBytes) async {
    if (kIsWeb) {
    // For Flutter Web
    final blob = html.Blob([imageBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download="enhanced_image_${DateTime.now().millisecondsSinceEpoch}.png"
      ..click();
    html.Url.revokeObjectUrl(url);}
    else{
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(imageBytes);

      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission not granted')),
            );
          }
          return;
        }
      }

      final result = await GallerySaver.saveImage(tempPath);
      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved to gallery')),
          );
        }
      } else {
        throw Exception('Failed to save image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e')),
        );
      }
    }
  }
    }

  void _onDownloadPressed() async {
    for (var img in _enhancedImages) {
      await _saveImage(img);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         backgroundColor: Colors.blue,
        title: Text('Result - ${widget.jobId}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Expanded(
                        child: _enhancedImages.isEmpty
                            ? const Center(child: Text('No images available'))
                            : ListView.builder(
                                itemCount: _enhancedImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey), // optional border
        borderRadius: BorderRadius.circular(8), // optional rounded corners
      ),
                              
                                    child: Image.memory(
                                      _enhancedImages[index],
                                      fit: BoxFit.contain,
                                    ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label:  Text('Download Image${_enhancedImages.length > 1 ? 's' : ''}'),
                        onPressed: _onDownloadPressed,
                      ),
                    ],
                  ),
                ),
    );
  }
}