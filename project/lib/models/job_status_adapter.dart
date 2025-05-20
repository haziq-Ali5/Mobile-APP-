import 'package:hive/hive.dart';
import 'package:project/constants/enums.dart';

class JobStatusAdapter extends TypeAdapter<JobStatus> {
  @override
  final int typeId = 2; // choose any unique integer

  @override
  JobStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return JobStatus.idle;
      case 1:
        return JobStatus.uploading;
      case 2:
        return JobStatus.processing;
      case 3:
        return JobStatus.completed;
      case 4:
        return JobStatus.failed;
      default:
        return JobStatus.idle;
    }
  }

  @override
  void write(BinaryWriter writer, JobStatus obj) {
    switch (obj) {
      case JobStatus.idle:
        writer.writeByte(0);
        break;
      case JobStatus.uploading:
        writer.writeByte(1);
        break;
      case JobStatus.processing:
        writer.writeByte(2);
        break;
      case JobStatus.completed:
        writer.writeByte(3);
        break;
      case JobStatus.failed:
        writer.writeByte(4);
        break;
      default:
        writer.writeByte(0);
        break;
    }
  }
}
