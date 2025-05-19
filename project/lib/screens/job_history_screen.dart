import 'package:flutter/material.dart';
import 'package:project/models/job.dart';
import 'package:project/services/database_helper.dart';
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
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<ProcessingJob> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final jobs = await _databaseHelper.getAllJobs();
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteJob(String jobId) async {
    try {
      await _databaseHelper.deleteJob(jobId);
      await _loadJobs();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          : _jobs.isEmpty
              ? const Center(child: Text('No enhancement history found'))
              : ListView.builder(
                  itemCount: _jobs.length,
                  itemBuilder: (context, index) {
                    final job = _jobs[index];
                    return _buildJobCard(context, job);
                  },
                ),
    );
  }

  Widget _buildJobCard(BuildContext context, ProcessingJob job) {
    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    
    final statusIcon = _getStatusIcon(job.status);
    final statusColor = _getStatusColor(job.status);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          'Job: ${job.jobId.substring(0, 8)}...',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${job.status.toString().split('.').last}'),
            Text('Created: ${_formatDate(job.createdAt)}'),
            if (job.message != null) 
              Text('Info: ${job.message}', 
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.secondary,
                ),
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
                  jobProvider.retryJob(job);
                  Navigator.pop(context);
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: () => _showDeleteConfirmDialog(job),
            ),
          ],
        ),
        onTap: job.status == JobStatus.completed
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultScreen(jobId: job.jobId),
                  ),
                )
            : null,
      ),
    );
  }

  void _showDeleteConfirmDialog(ProcessingJob job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}