import 'dart:async';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:project/models/job.dart';
import 'package:project/constants/enums.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // Initialize FFI for web
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        'image_enhancement.db',
        options: OpenDatabaseOptions(
          version: 2,  // Updated version for schema changes
          onCreate: _createDb,
          onUpgrade: _upgradeDb,
        ),
      );
    } else {
      // Mobile/Desktop initialization
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, 'image_enhancement.db');
      return await openDatabase(
        path,
        version: 2,  // Updated version for schema changes
        onCreate: _createDb,
        onUpgrade: _upgradeDb,
      );
    }
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE jobs(
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        result_url TEXT,
        local_image_path TEXT,
        error TEXT,
        batch_id TEXT,
        message TEXT,
        is_uploaded INTEGER NOT NULL DEFAULT 0,
        is_complete INTEGER NOT NULL DEFAULT 0,
        result_image BLOB
      )
    ''');
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Add the message column if upgrading from version 1
      await db.execute('ALTER TABLE jobs ADD COLUMN result_image BLOB');
    }
  }

  Future<String> saveEnhancedImageLocally(String jobId, Uint8List imageBytes) async {
    final db = await database;
    
    if (kIsWeb) {
      // Web: Save to browser storage
      final fileName = 'enhanced_$jobId.png';
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: imageBytes,
        mimeType: MimeType.png,
      );

      // Store filename reference
      await db.update(
        'jobs',
        {'local_image_path': fileName},
        where: 'id = ?',
        whereArgs: [jobId],
      );
      return fileName;
    } else {
      // Mobile/Desktop: Use file system
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/enhanced_images');
      if (!(await imagesDir.exists())) {
        await imagesDir.create(recursive: true);
      }
      final path = '${imagesDir.path}/$jobId.png';
      final file = File(path);
      await file.writeAsBytes(imageBytes);
      await db.update(
    'jobs',
    {
      'result_image': imageBytes,
      'local_image_path': kIsWeb ? null : path, // Only store path for mobile
    },
    where: 'id = ?',
    whereArgs: [jobId],
  );
      return path;
    }
  }

  Future<void> deleteJob(String jobId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'jobs',
      where: 'id = ?',
      whereArgs: [jobId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final localPath = maps[0]['local_image_path'] as String?;
      if (localPath != null && !kIsWeb) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }

    await db.delete(
      'jobs',
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  Future<List<ProcessingJob>> getAllJobs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('jobs', orderBy: 'created_at DESC');

    return maps.map((map) => ProcessingJob.fromMap(map)).toList();
  }

  Future<void> saveJob(ProcessingJob job) async {
    final db = await database;
    await db.insert(
      'jobs',
      job.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateJobStatus(
    String jobId,
    JobStatus status, {
    String? resultUrl,
    String? error,
    String? message,
  }) async {
    final db = await database;
    await db.update(
      'jobs',
      {
        'status': status.toString().split('.').last,
        'result_url': resultUrl,
        'error': error,
        'message': message,
        'is_complete': (status == JobStatus.completed || status == JobStatus.failed) ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  Future<void> clearAllJobs() async {
    final db = await database;
    await db.delete('jobs');
  }

  Future<List<ProcessingJob>> getPendingJobs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'jobs',
      where: 'is_complete = 0 AND error IS NULL',
    );

    return maps.map((map) => ProcessingJob.fromMap(map)).toList();
  }

  Future<void> updateJobMessage(String jobId, String message) async {
    final db = await database;
    await db.update(
      'jobs',
      {'message': message},
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }
}