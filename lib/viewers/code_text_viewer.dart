import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class CodeTextViewer extends StatefulWidget {
  final String filePath;
  final String searchQuery;
  final VoidCallback? onTap;

  const CodeTextViewer({
    super.key,
    required this.filePath,
    this.searchQuery = '',
    this.onTap,
  });

  @override
  State<CodeTextViewer> createState() => CodeTextViewerState();
}

class CodeTextViewerState extends State<CodeTextViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  String _content = '';
  List<String> _lines = [];

  bool _showLineNumbers = true;
  bool _wordWrap = true;
  double _fontSize = 13.0;

  // Markdown toggle
  bool _isMarkdownMode = false;
  bool _hasMarkdown = false;

  // Edit mode
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _checkMarkdown();
    _loadFile();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _checkMarkdown();
      _loadFile();
    }
  }

  void _checkMarkdown() {
    final ext = widget.filePath.split('.').last.toLowerCase();
    _hasMarkdown = (ext == 'md' || ext == 'markdown');
    _isMarkdownMode = _hasMarkdown;
  }

  void zoomIn() {
    setState(() {
      if (_fontSize < 24.0) _fontSize += 1.5;
    });
  }

  void zoomOut() {
    setState(() {
      if (_fontSize > 9.0) _fontSize -= 1.5;
    });
  }

  void toggleLineNumbers() {
    setState(() {
      _showLineNumbers = !_showLineNumbers;
    });
  }

  void toggleWordWrap() {
    setState(() {
      _wordWrap = !_wordWrap;
    });
  }

  void toggleMarkdownMode() {
    setState(() {
      _isMarkdownMode = !_isMarkdownMode;
    });
  }

  void toggleEditMode() {
    setState(() {
      if (!_isEditing) {
        _editController.text = _content;
        _isEditing = true;
      } else {
        _isEditing = false;
      }
    });
  }

  Future<void> saveEditedFile() async {
    try {
      final file = File(widget.filePath);
      await file.writeAsString(_editController.text);
      setState(() {
        _content = _editController.text;
        _lines = _content.split('\n');
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved successfully!'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e')),
        );
      }
    }
  }

  void prettifyJson() {
    try {
      final decoded = json.decode(_content);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      setState(() {
        _content = pretty;
        _lines = pretty.split('\n');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON formatted cleanly!'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot format invalid JSON: $e')),
      );
    }
  }

  void copyAllContent() {
    Clipboard.setData(ClipboardData(text: _content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Content copied to clipboard!'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isEditing = false;
    });

    try {
      final file = File(widget.filePath);
      final text = await file.readAsString();
      setState(() {
        _content = text;
        _lines = text.split('\n');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
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
              const Icon(Icons.code_off_rounded, size: 56, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('Could not open file as text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isEditing) {
      return Container(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _editController,
          maxLines: null,
          expands: true,
          style: TextStyle(
            fontSize: _fontSize,
            fontFamily: 'monospace',
            height: 1.5,
          ),
          decoration: const InputDecoration(
            hintText: 'Edit code/text...',
            border: InputBorder.none,
          ),
        ),
      );
    }

    if (_hasMarkdown && _isMarkdownMode) {
      return Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        child: Markdown(
          data: _content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(fontSize: _fontSize + 1, height: 1.6),
            code: TextStyle(
              fontSize: _fontSize,
              fontFamily: 'monospace',
              backgroundColor: isDark ? Colors.black38 : Colors.grey.shade200,
            ),
          ),
        ),
      );
    }

    final ext = widget.filePath.split('.').last.toLowerCase();
    final isJson = ext == 'json';

    return Column(
      children: [
        // Sub-toolbar for code controls
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: Row(
            children: [
              Text(
                '${_lines.length} lines',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const Spacer(),
              if (isJson) ...[
                InkWell(
                  onTap: prettifyJson,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('Prettify JSON', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (_hasMarkdown) ...[
                InkWell(
                  onTap: toggleMarkdownMode,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('Markdown Preview', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: toggleLineNumbers,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    _showLineNumbers ? 'Hide #s' : 'Show #s',
                    style: TextStyle(fontSize: 11, color: _showLineNumbers ? const Color(0xFF2563EB) : Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: toggleWordWrap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    _wordWrap ? 'Wrap On' : 'Wrap Off',
                    style: TextStyle(fontSize: 11, color: _wordWrap ? const Color(0xFF2563EB) : Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove, size: 14),
                tooltip: 'Zoom Out',
                onPressed: zoomOut,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.add, size: 14),
                tooltip: 'Zoom In',
                onPressed: zoomIn,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Code Viewer Body
        Expanded(
          child: Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF),
            child: _wordWrap
                ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _lines.length,
              itemBuilder: (context, idx) => _buildCodeLine(idx, isDark),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1200,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _lines.length,
                  itemBuilder: (context, idx) => _buildCodeLine(idx, isDark),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeLine(int index, bool isDark) {
    final line = _lines[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showLineNumbers)
            SizedBox(
              width: 44,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: _fontSize * 0.9,
                  fontFamily: 'monospace',
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
              ),
            ),
          if (_showLineNumbers) const SizedBox(width: 12),
          Expanded(
            child: _buildHighlightedText(
              line.isEmpty ? ' ' : line,
              widget.searchQuery,
              TextStyle(
                fontSize: _fontSize,
                fontFamily: 'monospace',
                height: 1.45,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty || !text.toLowerCase().contains(q)) {
      return SelectableText(text, style: style);
    }

    final spans = <TextSpan>[];
    int start = 0;
    final lower = text.toLowerCase();

    while (start < text.length) {
      final idx = lower.indexOf(q, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + q.length),
        style: style.copyWith(
          backgroundColor: Colors.amberAccent,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + q.length;
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
