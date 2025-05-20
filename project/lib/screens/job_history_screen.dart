// lib/screens/job_history_screen.dart

import 'package:flutter/material.dart';
import 'package:project/models/job.dart';
import 'package:project/screens/result_screen.dart';
import 'package:provider/provider.dart';
import 'package:project/providers/job_provider.dart';
import 'package:project/constants/enums.dart';

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});

  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadJobs();
  });
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);

    try {
      await Provider.of<JobProvider>(context, listen: false).loadJobs();
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load jobs: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteJob(String jobId) async {
    try {
      await Provider.of<JobProvider>(context, listen: false).deleteJob(jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting job: $e')),
        );
      }
    }
  }

  void _confirmDelete(ProcessingJob job) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteJob(job.jobId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(JobStatus status) {
    switch (status) {
      case JobStatus.completed:
        return Icons.check_circle;
      case JobStatus.failed:
        return Icons.error;
      case JobStatus.processing:
        return Icons.refresh;
      case JobStatus.uploading:
        return Icons.cloud_upload;
      case JobStatus.idle:
      default:
        return Icons.hourglass_empty;
    }
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.completed:
        return Colors.green;
      case JobStatus.failed:
        return Colors.red;
      case JobStatus.processing:
        return Colors.blue;
      case JobStatus.uploading:
        return Colors.orange;
      case JobStatus.idle:
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final jobs = context.watch<JobProvider>().jobs;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Enhancement History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : jobs.isEmpty
              ? const Center(child: Text('No enhancement history found'))
              : ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(job.status).withOpacity(0.2),
                          child: Icon(_getStatusIcon(job.status), color: _getStatusColor(job.status)),
                        ),
                        title: Text('Job: ${job.jobId.substring(0, 8)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${job.status.toString().split('.').last}'),
                            Text('Created: ${_formatDate(job.createdAt)}'),
                            if (job.message != null)
                              Text(
                                'Info: ${job.message}',
                                style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.secondary),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (job.status == JobStatus.failed)
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Retry',
                                onPressed: () {
                                  Provider.of<JobProvider>(context, listen: false).retryJob(job);
                                  Navigator.pop(context);
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDelete(job),
                            ),
                          ],
                        ),
                        onTap: job.status == JobStatus.completed
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ResultScreen(jobId: job.jobId),
                                  ),
                                )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
