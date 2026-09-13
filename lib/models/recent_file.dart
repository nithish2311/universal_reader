import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class RecentFile {
  final String path;
  final String name;
  final String extension;
  final int sizeBytes;
  final DateTime lastOpened;

  RecentFile({
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.lastOpened,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'extension': extension,
    'sizeBytes': sizeBytes,
    'lastOpened': lastOpened.toIso8601String(),
  };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
    path: json['path'] as String,
    name: json['name'] as String? ?? json['path'].toString().split(Platform.pathSeparator).last,
    extension: json['extension'] as String? ?? '',
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ?? DateTime.now(),
  );

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class RecentFilesManager {
  static const String _fileName = 'recent_files.json';
  static final List<RecentFile> _cache = [];
  static bool _isLoaded = false;

  static Future<File?> _getLocalFile() async {
    try {
      final dir = Directory.systemTemp;
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return null;
    }
  }

  static Future<List<RecentFile>> loadRecentFiles() async {
    if (_isLoaded) return List.unmodifiable(_cache);
    try {
      final file = await _getLocalFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final list = json.decode(content) as List<dynamic>;
        _cache.clear();
        for (final item in list) {
          try {
            final rf = RecentFile.fromJson(item as Map<String, dynamic>);
            if (File(rf.path).existsSync()) {
              _cache.add(rf);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error loading recent files: $e');
    }
    _isLoaded = true;
    _cache.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return List.unmodifiable(_cache);
  }

  static Future<void> addFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final stat = await file.stat();
      final name = path.split(Platform.pathSeparator).last;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

      _cache.removeWhere((item) => item.path == path);
      _cache.insert(
        0,
        RecentFile(
          path: path,
          name: name,
          extension: ext,
          sizeBytes: stat.size,
          lastOpened: DateTime.now(),
        ),
      );

      // Keep up to 30 recent files
      if (_cache.length > 30) {
        _cache.removeRange(30, _cache.length);
      }

      await _save();
    } catch (e) {
      debugPrint('Error adding recent file: $e');
    }
  }

  static Future<void> removeFile(String path) async {
    _cache.removeWhere((item) => item.path == path);
    await _save();
  }

  static Future<void> clearAll() async {
    _cache.clear();
    await _save();
  }

  static Future<void> _save() async {
    try {
      final file = await _getLocalFile();
      if (file != null) {
        final data = json.encode(_cache.map((e) => e.toJson()).toList());
        await file.writeAsString(data);
      }
    } catch (e) {
      debugPrint('Error saving recent files: $e');
    }
  }
}
