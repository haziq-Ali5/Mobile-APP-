// lib/services/hive_helper.dart

import 'package:hive/hive.dart';
import 'package:project/models/processing_job_hive.dart';

class HiveHelper {
  static final HiveHelper _instance = HiveHelper._internal();
  factory HiveHelper() => _instance;

  HiveHelper._internal();

  // This box must already be opened in main.dart via Hive.openBox<ProcessingJobHive>('jobs_box').
  Box<ProcessingJobHive> get _jobsBox => Hive.box<ProcessingJobHive>('jobs_box');

  /// Save or update a job by its jobId.
  Future<void> saveJob(ProcessingJobHive job) async {
    await _jobsBox.put(job.jobId, job);
  }

  /// Delete a specific job by jobId.
  Future<void> deleteJob(String jobId) async {
    await _jobsBox.delete(jobId);
  }

  /// Retrieve all jobs, sorted by createdAt descending.
  List<ProcessingJobHive> getAllJobs() {
    // Hive stores keys in insertion order, so if you want sorted by createdAt:
    final all = _jobsBox.values.toList();
    all.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
    return all;
  }

  /// Clear all jobs from the box.
  Future<void> clearAllJobs() async {
    await _jobsBox.clear();
  }

  /// Get a single job by ID (or null if not found).
  ProcessingJobHive? getJob(String jobId) {
    return _jobsBox.get(jobId);
  }

  /// Get all jobs that are not complete (example of filtering).
  List<ProcessingJobHive> getPendingJobs() {
    final all = _jobsBox.values.toList();
    return all.where((job) => !job.isComplete && job.error == null).toList();
  }
}
