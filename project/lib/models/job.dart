import 'package:project/constants/enums.dart';
import 'dart:typed_data';
class ProcessingJob {
  final String jobId;
  final JobStatus status;
  final DateTime createdAt;
  final Uint8List? resultImage;
  final String? error;
  final String? batchId;
  final String? resultUrl;  
  final String? message;
  final String? localImagePath;
  ProcessingJob({
    required this.jobId,
    required this.status,
    required this.createdAt,
    this.resultImage,
    this.error,
    this.batchId,
    this.resultUrl,         
    this.message,
    this.localImagePath,
  });

  bool get isComplete =>
      status == JobStatus.completed || status == JobStatus.failed;

  Map<String, dynamic> toMap() {
    return {
      'id': jobId,
      'status': status.toString().split('.').last,
      'created_at': createdAt.millisecondsSinceEpoch,
      'result_image': resultImage,
      'result_url': resultUrl,
      'error': error,
      'batch_id': batchId,
      'message': message,
      'localImagePath': localImagePath,
    };
  }

  factory ProcessingJob.fromMap(Map<String, dynamic> map) {
    return ProcessingJob(
      jobId: map['id'] ?? '',
      status: _parseStatus(map['status'] ?? 'processing'),
      createdAt: map['created_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
      resultImage: map['result_image'] != null 
        ? Uint8List.fromList(map['result_image']) 
        : null,
      resultUrl: map['result_url'],
      error: map['error'],
      batchId: map['batch_id'],
      message: map['message'],
      localImagePath: map['localImagePath'],
    );
  }

  static JobStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return JobStatus.completed;
      case 'failed':
        return JobStatus.failed;
      case 'processing':
        return JobStatus.processing;
      case 'uploading':
        return JobStatus.uploading;
      case 'idle':
        return JobStatus.idle;
      default:
        return JobStatus.processing;
    }
  }

  ProcessingJob copyWith({
    String? jobId,
    JobStatus? status,
    DateTime? createdAt,
    Uint8List? resultImage,
    String? resultUrl,
    String? error,
    String? batchId,
    String? message,
    String? localImagePath,
  }) {
    return ProcessingJob(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resultImage: resultImage ?? this.resultImage,
      resultUrl: resultUrl ?? this.resultUrl,
      error: error ?? this.error,
      batchId: batchId ?? this.batchId,
      message: message ?? this.message,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}
