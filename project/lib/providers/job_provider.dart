import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:project/constants/enums.dart';
import 'package:project/models/job.dart';
import 'package:project/services/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class JobProvider with ChangeNotifier {
  final ApiService _apiService;
  JobStatus _status = JobStatus.idle;
  final List<ProcessingJob> _jobs = [];
  WebSocketChannel? _channel;
  String? _latestJobId;
  
  JobProvider(this._apiService);
  
  JobStatus get status => _status;
  List<ProcessingJob> get jobs => List.unmodifiable(_jobs);
  String? get latestJobId => _latestJobId;
  
  // Upload a file from device
  Future<void> uploadImage(File image) async {
    try {
      _status = JobStatus.uploading;
      notifyListeners();
      
      final jobId = await _apiService.uploadImage(image);
      _processJob(jobId);
    } catch (e) {
      _status = JobStatus.failed;
      notifyListeners();
      rethrow;
    }
  }
  
  // Upload image bytes (for web or when image is already in memory)
  Future<void> uploadImageBytes(Uint8List imageBytes) async {
    try {
      _status = JobStatus.uploading;
      notifyListeners();
      
      final jobId = await _apiService.uploadImageBytes(imageBytes);
      _processJob(jobId);
    } catch (e) {
      _status = JobStatus.failed;
      notifyListeners();
      rethrow;
    }
  }
  
  // Common processing logic for both upload methods
  void _processJob(String jobId) {
    _latestJobId = jobId;
    _status = JobStatus.processing;
    
    // Add job to list
    _jobs.add(ProcessingJob(
      jobId: jobId,
      status: JobStatus.processing,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    
    // Connect to WebSocket for status updates
    _connectToWebSocket(jobId);
  }
  
  void _connectToWebSocket(String jobId) {
    try {
      // Close previous channel if exists
      _channel?.sink.close();
      
      // Connect to WebSocket
      // Use http://10.0.2.2:5000 for Android emulator to connect to localhost
      final wsUrl = 'ws://10.0.2.2:5000/ws/status/$jobId';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen for status updates
      _channel!.stream.listen(
        (data) {
          _handleStatusUpdate(jobId, data);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _pollJobStatus(jobId);
        },
        onDone: () {
          print('WebSocket connection closed');
          _pollJobStatus(jobId);
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
      _pollJobStatus(jobId);
    }
  }
  
  // Fallback to polling if WebSocket fails
  void _pollJobStatus(String jobId) async {
    try {
      while (true) {
        // Find the job in the list
        final jobIndex = _jobs.indexWhere((job) => job.jobId == jobId);
        if (jobIndex < 0) return;
        
        // Skip polling if job is already completed or failed
        if (_jobs[jobIndex].status == JobStatus.completed || 
            _jobs[jobIndex].status == JobStatus.failed) {
          return;
        }
        
        // Poll the status endpoint
        final status = await _apiService.checkJobStatus(jobId);
        _handleStatusUpdate(jobId, status);
        
        // Wait before polling again
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      print('Polling error: $e');
    }
  }
  
  void _handleStatusUpdate(String jobId, dynamic data) {
    // Parse the status from the received data
    final newStatus = _parseStatusFromString(data.toString());
    
    // Find the job in the list
    final jobIndex = _jobs.indexWhere((job) => job.jobId == jobId);
    if (jobIndex < 0) return;
    
    // Create updated job with new status
    final resultUrl = newStatus == JobStatus.completed 
        ? 'http://10.0.2.2:5000/result/$jobId' 
        : null;
        
    final updatedJob = ProcessingJob(
      jobId: jobId,
      status: newStatus,
      resultUrl: resultUrl,
      createdAt: _jobs[jobIndex].createdAt,
      error: newStatus == JobStatus.failed ? "Job failed" : null,
    );
    
    // Update the job in the list
    _jobs[jobIndex] = updatedJob;
    
    // Update current status if this is the latest job
    if (jobId == _latestJobId) {
      _status = newStatus;
    }
    
    notifyListeners();
  }
  
  JobStatus _parseStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return JobStatus.completed;
      case 'failed':
      case 'error':
        return JobStatus.failed;
      case 'processing':
        return JobStatus.processing;
      case 'uploading':
        return JobStatus.uploading;
      default:
        return JobStatus.processing;
    }
  }
  
  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}