// lib/providers/job_provider.dart

import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:project/constants/enums.dart';
import 'package:project/models/job.dart';
import 'package:project/models/processing_job_hive.dart';
import 'package:project/services/api_service.dart';
import 'package:project/services/hive_helper.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class JobProvider with ChangeNotifier {
  final ApiService _apiService;
  final HiveHelper _hiveHelper = HiveHelper();
  final Uuid _uuid = Uuid();

  String _userId = '';
  JobStatus _status = JobStatus.idle;
  final List<ProcessingJob> _jobs = [];
  IO.Socket? _socket;
  String? _latestJobId;
  static const String baseUrl = 'http://localhost:5000';
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? _currentBatchId;
  final Map<String, List<String>> _batches = {};

  JobProvider(this._apiService);

  void setUserId(String id) {
    _userId = id;
  }

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
    final jobsInBatch = _jobs.where((j) => j.batchId == batchId).toList();
    if (jobsInBatch.isEmpty) return 0.0;
    final completedCount = jobsInBatch.where((j) => j.status == JobStatus.completed).length;
    return completedCount / jobsInBatch.length;
  }

  Future<void> loadJobs() async {
    try {
      final hiveJobs = _hiveHelper.getAllJobs();
      _jobs
        ..clear()
        ..addAll(hiveJobs.map((hiveJob) => _fromHive(hiveJob)));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading jobs from Hive: $e');
    }
  }

  Future<List<String>> uploadFiles(List<Uint8List> files) async {
    try {
      _status = JobStatus.uploading;
      notifyListeners();

      startNewBatch();

      final jobIds = await _apiService.uploadFiles(files);
      debugPrint('Uploaded files, received job IDs: $jobIds');
      _batches[_currentBatchId!] = jobIds;

      for (final jobId in jobIds) {
        debugPrint("Job ID: $jobId");
        final now = DateTime.now();

        final jobModel = ProcessingJob(
          jobId: jobId,
          userId: _userId,
          status: JobStatus.processing,
          createdAt: now,
          batchId: _currentBatchId,
          resultUrl: null,
          error: null,
          message: null,
          localImagePath: null,
          resultImage: null,
        );

        final hiveJob = ProcessingJobHive(
          jobId: jobId,
          userId: _userId,
          status: JobStatus.processing,
          createdAtMillis: now.millisecondsSinceEpoch,
          resultUrl: null,
          localImagePath: null,
          error: null,
          batchId: _currentBatchId,
          message: null,
          isComplete: false,
          resultImage: null,
        );

        try {
          await _hiveHelper.saveJob(hiveJob);
        } catch (e) {
          debugPrint("Failed to save job to Hive: $e");
        }

        _jobs.add(jobModel);
        _processJob(jobId);
      }

      _status = JobStatus.processing;
      notifyListeners();

      return jobIds;
    } catch (e) {
      _status = JobStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> uploadImageBytes(Uint8List imageBytes) async {
    try {
      _status = JobStatus.uploading;
      notifyListeners();

      startNewBatch();
      final jobId = await _apiService.uploadImageBytes(imageBytes);
      final now = DateTime.now();

      final jobModel = ProcessingJob(
        jobId: jobId,
        userId: _userId,
        status: JobStatus.processing,
        createdAt: now,
        batchId: _currentBatchId,
        resultUrl: null,
        error: null,
        message: null,
        localImagePath: null,
        resultImage: null,
      );

      final hiveJob = ProcessingJobHive(
        jobId: jobId,
        userId: _userId,
        status: JobStatus.processing,
        createdAtMillis: now.millisecondsSinceEpoch,
        resultUrl: null,
        localImagePath: null,
        error: null,
        batchId: _currentBatchId,
        message: null,
        isComplete: false,
        resultImage: null,
      );
      await _hiveHelper.saveJob(hiveJob);

      _jobs.add(jobModel);
      _processJob(jobId);

      _status = JobStatus.processing;
      notifyListeners();
    } catch (e) {
      _status = JobStatus.failed;
      notifyListeners();
      rethrow;
    }
  }

  void _processJob(String jobId) {
    _latestJobId = jobId;
    _status = JobStatus.processing;
    notifyListeners();
    _connectToSocket(jobId);
  }

  void _connectToSocket(String jobId) {
    try {
      _socket?.disconnect();
      _socket = IO.io(
        '$baseUrl/ws/jobs',
        IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().enableForceNew().build(),
      );

      _socket!.onConnect((_) {
        debugPrint('Connected to Socket.IO');
        _socket!.emit('subscribe', {'job_id': jobId});
      });

      _socket!.on('job_received', (data) {
        _handleStatusUpdate(jobId, {
          'status': 'received',
          'message': data['message'],
        });
      });

      _socket!.on('status_update', (data) {
        _handleStatusUpdate(jobId, data);
      });

      _socket!.onError((err) {
        _pollJobStatus(jobId);
      });

      _socket!.onDisconnect((_) {
        _pollJobStatus(jobId);
      });

      _socket!.connect();
    } catch (e) {
      _pollJobStatus(jobId);
    }
  }

  void _pollJobStatus(String jobId) async {
    try {
      while (_jobs.any((j) => j.jobId == jobId && !j.isComplete)) {
        final statusStr = await _apiService.checkJobStatus(jobId);
        _handleStatusUpdate(jobId, {'status': statusStr});
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  void _handleStatusUpdate(String jobId, dynamic data) {
  Future.microtask(() async {
    try {
      final newStatus = _parseStatusFromString(data['status'].toString());
      final jobIndex = _jobs.indexWhere((j) => j.jobId == jobId);
      if (jobIndex == -1) return;

      // Update in-memory ProcessingJob
      final updatedJob = _jobs[jobIndex].copyWith(
        status: newStatus,
        resultUrl: newStatus == JobStatus.completed
            ? '$baseUrl/result/$jobId'
            : null,
        error: data['error']?.toString(),
        message: data['message']?.toString(),
      );

      _jobs[jobIndex] = updatedJob;

      // Update Hive entry
      final hiveJob = _hiveHelper.getJob(jobId);
      if (hiveJob != null) {
        final newHive = ProcessingJobHive(
          jobId: hiveJob.jobId,
          userId: hiveJob.userId,
          status: newStatus,
          createdAtMillis: hiveJob.createdAtMillis,
          resultUrl: updatedJob.resultUrl,
          localImagePath: updatedJob.localImagePath,
          error: updatedJob.error,
          batchId: hiveJob.batchId,
          message: updatedJob.message,
          isComplete: (newStatus == JobStatus.completed ||
              newStatus == JobStatus.failed),
          resultImage: updatedJob.resultImage,
        );
        await _hiveHelper.saveJob(newHive);
      }

         WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      debugPrint('Job $jobId updated to: $newStatus');
      if (data['message'] != null) {
        debugPrint('Message: ${data['message']}');
      }
    } catch (e) {
      debugPrint('Status update error: $e');
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

  Future<void> retryJob(ProcessingJob job) async {
    try {
      final jobIndex = _jobs.indexWhere((j) => j.jobId == job.jobId);
      final now = job.createdAt;
      final newJobModel = job.copyWith(
        status: JobStatus.processing,
        error: null,
        message: null,
        localImagePath: null,
        resultImage: null,
        resultUrl: null,
      );

      if (jobIndex >= 0) {
        _jobs[jobIndex] = newJobModel;
      } else {
        _jobs.add(newJobModel);
      }

      final hiveJob = ProcessingJobHive(
        jobId: job.jobId,
        userId: job.userId,
        status: JobStatus.processing,
        createdAtMillis: now.millisecondsSinceEpoch,
        resultUrl: null,
        localImagePath: null,
        error: null,
        batchId: job.batchId,
        message: null,
        isComplete: false,
        resultImage: null,
      );
      await _hiveHelper.saveJob(hiveJob);

      _latestJobId = job.jobId;
      _status = JobStatus.processing;
      notifyListeners();

      _connectToSocket(job.jobId);
    } catch (e) {
      final failedModel = job.copyWith(status: JobStatus.failed, error: e.toString());
      final idx = _jobs.indexWhere((j) => j.jobId == job.jobId);
      if (idx >= 0) _jobs[idx] = failedModel;

      final oldHive = _hiveHelper.getJob(job.jobId);
      if (oldHive != null) {
        final failedHive = ProcessingJobHive(
          jobId: oldHive.jobId,
          userId: oldHive.userId,
          status: JobStatus.failed,
          createdAtMillis: oldHive.createdAtMillis,
          resultUrl: oldHive.resultUrl,
          localImagePath: oldHive.localImagePath,
          error: e.toString(),
          batchId: oldHive.batchId,
          message: oldHive.message,
          isComplete: true,
          resultImage: oldHive.resultImage,
        );
        await _hiveHelper.saveJob(failedHive);
      }

      notifyListeners();
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      _jobs.removeWhere((j) => j.jobId == jobId);
      await _hiveHelper.deleteJob(jobId);
      if (_latestJobId == jobId) {
        _latestJobId = null;
        _status = JobStatus.idle;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Delete job error: $e');
    }
  }

  Future<void> clearAllJobs() async {
    try {
      _jobs.clear();
      await _hiveHelper.clearAllJobs();
      _latestJobId = null;
      _status = JobStatus.idle;
      notifyListeners();
    } catch (e) {
      debugPrint('Clear jobs error: $e');
    }
  }

  Future<void> cleanupCompletedBatches() async {
    try {
      final completedBatches = _batches.keys.where((batchId) {
        final batchJobs = _jobs.where((j) => j.batchId == batchId).toList();
        return batchJobs.every((j) => j.status == JobStatus.completed);
      }).toList();

      for (final batchId in completedBatches) {
        _batches.remove(batchId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Batch cleanup error: $e');
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }

  ProcessingJob _fromHive(ProcessingJobHive hive) {
    return ProcessingJob(
      jobId: hive.jobId,
      userId: hive.userId,
      status: hive.status,
      createdAt: DateTime.fromMillisecondsSinceEpoch(hive.createdAtMillis),
      resultUrl: hive.resultUrl,
      localImagePath: hive.localImagePath,
      error: hive.error,
      batchId: hive.batchId,
      message: hive.message,
      resultImage: hive.resultImage,
    );
  }
}
