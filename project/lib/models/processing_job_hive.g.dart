// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processing_job_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProcessingJobHiveAdapter extends TypeAdapter<ProcessingJobHive> {
  @override
  final int typeId = 0;

  @override
  ProcessingJobHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProcessingJobHive(
      jobId: fields[0] as String,
      userId: fields[1] as String,
      status: fields[2] as JobStatus,
      createdAtMillis: fields[3] as int,
      resultUrl: fields[4] as String?,
      localImagePath: fields[5] as String?,
      error: fields[6] as String?,
      batchId: fields[7] as String?,
      message: fields[8] as String?,
      isComplete: fields[9] as bool,
      resultImage: fields[10] as Uint8List?,
    );
  }

  @override
  void write(BinaryWriter writer, ProcessingJobHive obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.jobId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.createdAtMillis)
      ..writeByte(4)
      ..write(obj.resultUrl)
      ..writeByte(5)
      ..write(obj.localImagePath)
      ..writeByte(6)
      ..write(obj.error)
      ..writeByte(7)
      ..write(obj.batchId)
      ..writeByte(8)
      ..write(obj.message)
      ..writeByte(9)
      ..write(obj.isComplete)
      ..writeByte(10)
      ..write(obj.resultImage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessingJobHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
