// lib/models/processing_job_hive.dart

import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:project/constants/enums.dart';

part 'processing_job_hive.g.dart';

@HiveType(typeId: 1)
class ProcessingJobHive extends HiveObject {
  @HiveField(0)
  final String jobId;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final JobStatus status;

  @HiveField(3)
  final int createdAtMillis;

  @HiveField(4)
  final String? resultUrl;

  @HiveField(5)
  final String? localImagePath;

  @HiveField(6)
  final String? error;

  @HiveField(7)
  final String? batchId;

  @HiveField(8)
  final String? message;

  @HiveField(9)
  final bool isComplete;

  @HiveField(10)
  final Uint8List? resultImage;

  ProcessingJobHive({
    required this.jobId,
    required this.userId,
    required this.status,
    required this.createdAtMillis,
    this.resultUrl,
    this.localImagePath,
    this.error,
    this.batchId,
    this.message,
    this.isComplete = false,
    this.resultImage,
  });
}
