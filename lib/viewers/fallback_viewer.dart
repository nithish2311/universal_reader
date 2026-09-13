import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/format_helper.dart';

class FallbackViewer extends StatefulWidget {
  final String filePath;
  final VoidCallback onOpenAsText;
  final VoidCallback onShare;

  const FallbackViewer({
    super.key,
    required this.filePath,
    required this.onOpenAsText,
    required this.onShare,
  });

  @override
  State<FallbackViewer> createState() => _FallbackViewerState();
}

class _FallbackViewerState extends State<FallbackViewer> {
  int _fileSizeBytes = 0;
  DateTime? _modified;
  bool _showHexDump = false;
  String _hexDump = '';

  @override
  void initState() {
    super.initState();
    _loadFileStats();
  }

  Future<void> _loadFileStats() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        setState(() {
          _fileSizeBytes = stat.size;
          _modified = stat.modified;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHexDump() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.openRead(0, 512).expand((e) => e).toList();
      final buffer = StringBuffer();
      for (int i = 0; i < bytes.length; i += 16) {
        final chunk = bytes.sublist(i, (i + 16 > bytes.length) ? bytes.length : i + 16);
        final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        final ascii = chunk.map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.').join('');
        buffer.writeln('${i.toRadixString(16).padLeft(4, '0')}: ${hex.padRight(48)}  $ascii');
      }
      setState(() {
        _hexDump = buffer.toString();
        _showHexDump = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read hex dump: $e')),
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
    final fileName = widget.filePath.split(Platform.pathSeparator).last;
    final ext = FormatHelper.getExtension(widget.filePath);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insert_drive_file_rounded,
                  size: 64,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                fileName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ext.toUpperCase().isEmpty ? 'UNKNOWN' : '${ext.toUpperCase()} FILE',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 24),

              // File Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('File Size', _formatBytes(_fileSizeBytes)),
                    if (_modified != null) ...[
                      const Divider(height: 16),
                      _buildInfoRow('Last Modified', _modified.toString().split('.').first),
                    ],
                    const Divider(height: 16),
                    _buildInfoRow('Location', widget.filePath, isPath: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: widget.onShare,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share File'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenAsText,
                    icon: const Icon(Icons.text_snippet_rounded, size: 18),
                    label: const Text('Preview as Text'),
                  ),
                  TextButton.icon(
                    onPressed: _showHexDump ? () => setState(() => _showHexDump = false) : _loadHexDump,
                    icon: Icon(_showHexDump ? Icons.visibility_off_rounded : Icons.terminal_rounded, size: 18),
                    label: Text(_showHexDump ? 'Hide Hex Dump' : 'View Hex Dump'),
                  ),
                ],
              ),

              if (_showHexDump && _hexDump.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      _hexDump,
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: isPath ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
