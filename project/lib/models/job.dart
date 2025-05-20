// lib/models/job.dart

import 'dart:typed_data';
import 'package:project/constants/enums.dart';

/// This is your app-level “ProcessingJob” model. 
/// It no longer needs to include SQLite mapping (toMap/fromMap).
/// Persisted storage is handled via `ProcessingJobHive` and `HiveHelper`.
class ProcessingJob {
  final String jobId;
  final String userId;
  final JobStatus status;
  final DateTime createdAt;
  final Uint8List? resultImage;
  final String? resultUrl;
  final String? localImagePath;
  final String? error;
  final String? batchId;
  final String? message;

  ProcessingJob({
    required this.jobId,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.resultImage,
    this.resultUrl,
    this.localImagePath,
    this.error,
    this.batchId,
    this.message,
  });

  /// Derived property: true if the job is done or failed.
  bool get isComplete =>
      status == JobStatus.completed || status == JobStatus.failed;

  /// Creates a copy of this job, overriding only the provided fields.
  ProcessingJob copyWith({
    String? jobId,
    String? userId,
    JobStatus? status,
    DateTime? createdAt,
    Uint8List? resultImage,
    String? resultUrl,
    String? localImagePath,
    String? error,
    String? batchId,
    String? message,
  }) {
    return ProcessingJob(
      jobId: jobId ?? this.jobId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resultImage: resultImage ?? this.resultImage,
      resultUrl: resultUrl ?? this.resultUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      error: error ?? this.error,
      batchId: batchId ?? this.batchId,
      message: message ?? this.message,
    );
  }
}
