
import 'package:project/constants/enums.dart';
class ProcessingJob {
  final String jobId;
  final JobStatus status;
  final String? resultUrl;
  final DateTime createdAt;
  final String? error;

  ProcessingJob({
    required this.jobId,
    required this.status,
    this.resultUrl,
    required this.createdAt,
    this.error,
  });
}