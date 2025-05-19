import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Base URL for the API
  // Use 10.0.2.2 for Android emulator to connect to localhost
  final String baseUrl = 'http://localhost:5000';
  
  // API endpoints
  final String uploadEndpoint = '/jobs';
  final String statusEndpoint = '/status';
  final String resultEndpoint = '/result';
  
  // Upload image files
  Future<List<String>> uploadFiles(List<Uint8List> files) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$uploadEndpoint'));

      for (var i = 0; i < files.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            files[i],
            filename: 'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            contentType: MediaType('image', 'jpeg'),
          )
        );
      }

      final response = await http.Response.fromStream(await request.send());
      
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        return responseData.map<String>((j) => j['job_id'].toString()).toList();
      } else {
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      rethrow;
    }
  }

  // Deprecated single-image methods
  Future<String> uploadImage(File image) async => 
      (await uploadFiles([await image.readAsBytes()])).first;

  Future<String> uploadImageBytes(Uint8List bytes) async => 
      (await uploadFiles([bytes])).first;

  // Check job status
  Future<String> checkJobStatus(String jobId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$statusEndpoint/$jobId'));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['status'];
      } else {
        throw Exception('Failed to check job status: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error checking job status: $e');
      throw Exception('Failed to check job status: $e');
    }
  }

  // Get all enhanced images for a job (renamed to match what you're calling)
  Future<List<Uint8List>> getEnhancedImages(String jobId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$resultEndpoint/$jobId/all'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map<Uint8List>((base64Str) => base64Decode(base64Str)).toList();
      } else {
        throw Exception('Failed to get enhanced images: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting enhanced images: $e');
      throw Exception('Failed to get enhanced images: $e');
    }
  }

  // Get a single enhanced image (optional, for legacy calls)
  Future<Uint8List> getEnhancedImage(String jobId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$resultEndpoint/$jobId'));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to get enhanced image: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting enhanced image: $e');
      throw Exception('Failed to get enhanced image: $e');
    }
  }

  // Generate fake job ID (for testing)
  String generateFakeJobId() {
    const uuid = Uuid();
    return uuid.v4();
  }

  // Simulate job completion
  Future<void> simulateJobCompletion(String jobId) async {
    await Future.delayed(const Duration(seconds: 3));
    return;
  }
}
