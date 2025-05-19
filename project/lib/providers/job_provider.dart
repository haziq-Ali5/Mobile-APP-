import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:project/constants/enums.dart';
import 'package:project/models/job.dart';
import 'package:project/services/api_service.dart';
import 'package:project/services/database_helper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

class JobProvider with ChangeNotifier {
  final ApiService _apiService;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Uuid _uuid = Uuid();
  JobStatus _status = JobStatus.idle;
  final List<ProcessingJob> _jobs = [];
  WebSocketChannel? _channel;
  String? _latestJobId;
  static const String baseUrl = 'http://localhost:5000';
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? _currentBatchId;
  final Map<String, List<String>> _batches = {}; // batchId -> List<jobId>

  JobProvider(this._apiService);

  JobStatus get status => _status;
  List<ProcessingJob> get jobs => List.unmodifiable(_jobs);
  String? get latestJobId => _latestJobId;
  String? get currentBatchId => _currentBatchId;
  Map<String, List<String>> get batches => Map.unmodifiable(_batches);

  void startNewBatch() {
    _currentBatchId = _uuid.v4();
    _batches[_currentBatchId!] = [];
  }

  double getBatchProgress(String batchId) {
    final jobs = _jobs.where((j) => j.batchId == batchId).toList();
    if (jobs.isEmpty) return 0.0;
    final completedCount = jobs.where((j) => j.status == JobStatus.completed).length;
    return completedCount / jobs.length;
  }

  Future<void> loadJobs() async {
    try {
      final savedJobs = await _databaseHelper.getAllJobs();
      _jobs
        ..clear()
        ..addAll(savedJobs);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading jobs: $e');
    }
  }

  /// Upload multiple files in a batch.
  Future<List<String>> uploadFiles(List<Uint8List> files) async {
  try {
    _status = JobStatus.uploading;
    notifyListeners();

    startNewBatch();  // Always start a new batch

    // API call returns list of job IDs for the batch
    final jobIds = await _apiService.uploadFiles(files);
    debugPrint('Uploaded files, received job IDs: $jobIds');
    _batches[_currentBatchId!] = jobIds;

    for (final jobId in jobIds) {
      final job = ProcessingJob(
        jobId: jobId,
        status: JobStatus.processing,
        createdAt: DateTime.now(),
        batchId: _currentBatchId,
      );
      await _databaseHelper.saveJob(job);
      _jobs.add(job);
      _processJob(jobId);
    }

    _status = JobStatus.processing;
    notifyListeners();

    // Return the first jobId in the list (assuming there is at least one)
    if (jobIds.isNotEmpty) {
      return jobIds;
    } else {
      throw Exception('No job IDs returned from upload');
    }
  } catch (e) {
    _status = JobStatus.failed;
    notifyListeners();
    rethrow;
  }
}


  /// Upload a single image (if needed)
  Future<void> uploadImageBytes(Uint8List imageBytes) async {
    try {
      _status = JobStatus.uploading;
      notifyListeners();

      startNewBatch();
      final jobId = await _apiService.uploadImageBytes(imageBytes);

      final job = ProcessingJob(
        jobId: jobId,
        status: JobStatus.processing,
        createdAt: DateTime.now(),
        batchId: _currentBatchId,
      );
      await _databaseHelper.saveJob(job);
      _jobs.add(job);

      _processJob(jobId);

      _status = JobStatus.processing;
      notifyListeners();
    } catch (e) {
      _status = JobStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> retryJob(ProcessingJob job) async {
    try {
      final jobIndex = _jobs.indexWhere((j) => j.jobId == job.jobId);
      final newJob = ProcessingJob(
        jobId: job.jobId,
        status: JobStatus.processing,
        createdAt: job.createdAt,
        batchId: job.batchId,
      );

      if (jobIndex >= 0) {
        _jobs[jobIndex] = newJob;
      } else {
        _jobs.add(newJob);
      }

      await _databaseHelper.updateJobStatus(job.jobId, JobStatus.processing);

      // Keep tracking this as latest if it's most recent
      _latestJobId = job.jobId;
      _status = JobStatus.processing;

      notifyListeners();
      _connectToWebSocket(job.jobId);
    } catch (e) {
      debugPrint('Error retrying job: $e');

      final failedJob = ProcessingJob(
        jobId: job.jobId,
        status: JobStatus.failed,
        createdAt: job.createdAt,
        error: e.toString(),
      );

      final jobIndex = _jobs.indexWhere((j) => j.jobId == job.jobId);
      if (jobIndex >= 0) _jobs[jobIndex] = failedJob;

      await _databaseHelper.updateJobStatus(
        job.jobId,
        JobStatus.failed,
        error: e.toString(),
      );

      notifyListeners();
    }
  }

  void _processJob(String jobId) {
    _latestJobId = jobId;
    _status = JobStatus.processing;
    notifyListeners();
    _connectToWebSocket(jobId);
  }

  void _connectToWebSocket(String jobId) {
  try {
    _channel?.sink.close();
    _channel = IOWebSocketChannel.connect(
      Uri.parse('ws://localhost:5000/ws/jobs'),
      protocols: ['socket.io'],
    );

    _channel?.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data);
          debugPrint('WebSocket message: $message');
          
          if (message['event'] == 'job_received') {
            // Handle initial receipt confirmation
            debugPrint('Server received image: ${message['data']['message']}');
            _handleStatusUpdate(jobId, {
              'status': 'received',
              'message': message['data']['message']
            });
          }
          else if (message['event'] == 'status_update') {
            _handleStatusUpdate(jobId, message['data']);
          }
        } catch (e) {
          debugPrint('WebSocket message error: $e');
        }
      },
      onError: (err) {
        debugPrint('WebSocket error: $err');
        _pollJobStatus(jobId);
      },
      onDone: () {
        debugPrint('WebSocket closed');
        _pollJobStatus(jobId);
      },
    );

    // Send subscription message
    _channel?.sink.add(jsonEncode({
      'type': 'subscribe',
      'job_id': jobId,
    }));

  } catch (e) {
    debugPrint('WebSocket connection failed: $e');
    _pollJobStatus(jobId);
  }
}

  void _pollJobStatus(String jobId) async {
    try {
      while (_jobs.any((j) => j.jobId == jobId && !j.isComplete)) {
        final status = await _apiService.checkJobStatus(jobId);
        _handleStatusUpdate(jobId, status);
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }
Future<void> cleanupCompletedBatches() async {
  try {
    // Get all batch IDs with completed jobs
    final completedBatches = _batches.keys.where((batchId) {
      final batchJobs = _jobs.where((j) => j.batchId == batchId).toList();
      return batchJobs.every((j) => j.status == JobStatus.completed);
    }).toList();

    // Remove completed batches
    for (final batchId in completedBatches) {
      _batches.remove(batchId);
    }

    notifyListeners();
  } catch (e) {
    debugPrint('Error cleaning up batches: $e');
  }
}
  void _handleStatusUpdate(String jobId, dynamic data) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final newStatus = _parseStatusFromString(data['status'].toString());
      final jobIndex = _jobs.indexWhere((j) => j.jobId == jobId);
      
      if (jobIndex == -1) return;

      final updatedJob = _jobs[jobIndex].copyWith(
        status: newStatus,
        resultUrl: newStatus == JobStatus.completed 
          ? '$baseUrl/result/$jobId' 
          : null,
        error: data['error']?.toString(),
        message: data['message']?.toString(), // Add this line
      );

      _jobs[jobIndex] = updatedJob;
      await _databaseHelper.updateJobStatus(
        jobId,
        newStatus,
        resultUrl: updatedJob.resultUrl,
        error: updatedJob.error,
      );

      notifyListeners();

      // Add debug prints to track status
      debugPrint('Job $jobId status updated to: $newStatus');
      if (data['message'] != null) {
        debugPrint('Message: ${data['message']}');
      }

    } catch (e) {
      debugPrint('Error handling status update: $e');
    }
  });
}

  JobStatus _parseStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return JobStatus.completed;
      case 'failed':
      case 'error':
        return JobStatus.failed;
      case 'uploading':
        return JobStatus.uploading;
      default:
        return JobStatus.processing;
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      _jobs.removeWhere((j) => j.jobId == jobId);
      await _databaseHelper.deleteJob(jobId);
      if (_latestJobId == jobId) {
        _latestJobId = null;
        _status = JobStatus.idle;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting job: $e');
    }
  }

  Future<void> clearAllJobs() async {
    try {
      _jobs.clear();
      await _databaseHelper.clearAllJobs();
      _latestJobId = null;
      _status = JobStatus.idle;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing jobs: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
