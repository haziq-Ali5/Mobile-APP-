import 'package:flutter/material.dart';
import 'package:project/providers/job_provider.dart';
import 'package:provider/provider.dart';
import 'package:project/constants/enums.dart';
class StatusIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final jobProvider = Provider.of<JobProvider>(context);
    
    return Column(
      children: [
        if (jobProvider.status == JobStatus.uploading)
          CircularProgressIndicator(),
        if (jobProvider.status == JobStatus.processing)
          Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Processing...'),
            ],
          ),
        if (jobProvider.status == JobStatus.failed)
          Icon(Icons.error, color: Colors.red),
      ],
    );
  }
}