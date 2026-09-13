import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import '../utils/format_helper.dart';

class ArchiveViewer extends StatefulWidget {
  final String filePath;
  final VoidCallback? onTap;

  const ArchiveViewer({
    super.key,
    required this.filePath,
    this.onTap,
  });

  @override
  State<ArchiveViewer> createState() => ArchiveViewerState();
}

class ArchiveViewerState extends State<ArchiveViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ArchiveFile> _files = [];

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  @override
  void didUpdateWidget(covariant ArchiveViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadArchive();
    }
  }

  Future<void> _loadArchive() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final validFiles = archive.files.toList();
      validFiles.sort((a, b) {
        if (a.isFile && !b.isFile) return 1;
        if (!a.isFile && b.isFile) return -1;
        return a.name.compareTo(b.name);
      });

      setState(() {
        _files = validFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _previewArchiveFile(ArchiveFile file) {
    if (!file.isFile) return;
    final ext = FormatHelper.getExtension(file.name);
    final category = FormatHelper.getCategory(file.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(FormatHelper.getCategoryIcon(category), color: FormatHelper.getCategoryColor(category)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          file.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _buildInsidePreview(file, category, ext, scrollController),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInsidePreview(ArchiveFile file, FileCategory category, String ext, ScrollController controller) {
    if (file.content is! List<int>) {
      return const Center(child: Text('Cannot read file content.'));
    }

    final bytes = file.content as List<int>;

    if (category == FileCategory.image) {
      return InteractiveViewer(
        child: Center(
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    // Try text preview
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      return SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
        ),
      );
    } catch (_) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Binary file (${_formatBytes(file.size)})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Direct preview not available for this binary format in archive.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.archive_outlined, size: 56, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('Could not open archive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _files.length,
      separatorBuilder: (context, idx) => Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      itemBuilder: (context, idx) {
        final f = _files[idx];
        final isDir = !f.isFile;
        final category = isDir ? null : FormatHelper.getCategory(f.name);

        return ListTile(
          leading: Icon(
            isDir ? Icons.folder_rounded : FormatHelper.getCategoryIcon(category!),
            color: isDir ? Colors.amber : FormatHelper.getCategoryColor(category!),
            size: 26,
          ),
          title: Text(
            f.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isDir ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          subtitle: isDir ? null : Text(_formatBytes(f.size), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: isDir ? null : const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          onTap: () => _previewArchiveFile(f),
        );
      },
    );
  }
}
