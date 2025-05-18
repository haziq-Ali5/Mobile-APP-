import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:project/services/storage_service.dart';

class ApiService {
  final StorageService _storageService;
  
  // Use 10.0.2.2 for Android emulator to connect to localhost
  static const String _baseUrl = 'http://10.0.2.2:5000';
  
  ApiService(this._storageService);

  // Upload an image file from device
  Future<String> uploadImage(File image) async {
    final token = await _storageService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found');
    }
    
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/jobs'));
    
    // Add auth header
    request.headers['Authorization'] = 'Bearer $token';
    
    // Add the file
    request.files.add(await http.MultipartFile.fromPath('images', image.path));
    
    // Send the request
    final response = await request.send();
    
    // Parse the response
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(await response.stream.bytesToString());
      
      // Handle array response (multiple jobs)
      if (jsonResponse is List) {
        return jsonResponse[0]['job_id'] as String;
      }
      
      // Handle single job response
      return jsonResponse['job_id'] as String;
    } else {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Upload failed: ${response.statusCode} - $errorBody');
    }
  }
  
  // Upload image bytes (for web or when already in memory)
  Future<String> uploadImageBytes(Uint8List imageBytes) async {
    final token = await _storageService.getToken();
    if (token == null) {
      throw Exception('Authentication token not found');
    }
    
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/jobs'));
    
    // Add auth header
    request.headers['Authorization'] = 'Bearer $token';
    
    // Add the image bytes as a file
    request.files.add(http.MultipartFile.fromBytes(
      'images', 
      imageBytes,
      filename: 'image.jpg',
    ));
    
    // Send the request
    final response = await request.send();
    
    // Parse the response
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(await response.stream.bytesToString());
      
      // Handle array response (multiple jobs)
      if (jsonResponse is List) {
        return jsonResponse[0]['job_id'] as String;
      }
      
      // Handle single job response
      return jsonResponse['job_id'] as String;
    } else {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Upload failed: ${response.statusCode} - $errorBody');
    }
  }

  // Check job status
  Future<String> checkJobStatus(String jobId) async {
    final url = Uri.parse('$_baseUrl/status/$jobId');
    final token = await _storageService.getToken();
    
    final response = await http.get(
      url,
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['status'];
    } else {
      throw Exception('Failed to check job status: ${response.statusCode}');
    }
  }
  
  // Get enhanced image
  Future<Uint8List> getEnhancedImage(String jobId) async {
    final url = Uri.parse('$_baseUrl/result/$jobId');
    final token = await _storageService.getToken();
    
    final response = await http.get(
      url,
      headers: token != null ? {'Authorization': 'Bearer $token'} : {},
    );
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to get enhanced image: ${response.statusCode}');
    }
  }
}