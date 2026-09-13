import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;

class DocParagraph {
  final String text;
  final bool isHeading;
  final bool isBullet;

  DocParagraph({
    required this.text,
    this.isHeading = false,
    this.isBullet = false,
  });
}

class DocxViewer extends StatefulWidget {
  final String filePath;
  final String searchQuery;
  final VoidCallback? onTap;

  const DocxViewer({
    super.key,
    required this.filePath,
    this.searchQuery = '',
    this.onTap,
  });

  @override
  State<DocxViewer> createState() => DocxViewerState();
}

class DocxViewerState extends State<DocxViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DocParagraph> _paragraphs = [];
  double _fontSize = 15.0;

  @override
  void initState() {
    super.initState();
    _loadDocx();
  }

  @override
  void didUpdateWidget(covariant DocxViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadDocx();
    }
  }

  void zoomIn() {
    setState(() {
      if (_fontSize < 24.0) _fontSize += 1.5;
    });
  }

  void zoomOut() {
    setState(() {
      if (_fontSize > 11.0) _fontSize -= 1.5;
    });
  }

  Future<void> _loadDocx() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _paragraphs = [];
    });

    try {
      final ext = widget.filePath.split('.').last.toLowerCase();
      if (ext == 'rtf') {
        final content = await File(widget.filePath).readAsString();
        // Basic RTF stripping
        final clean = content.replaceAll(RegExp(r'\\[a-z0-9]+ ?', caseSensitive: false), '').replaceAll(RegExp(r'[{}]'), '');
        final lines = clean.split('\n').where((l) => l.trim().isNotEmpty).map((l) => DocParagraph(text: l.trim())).toList();
        setState(() {
          _paragraphs = lines;
          _isLoading = false;
        });
        return;
      }

      final bytes = await File(widget.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docXml = archive.findFile('word/document.xml');
      if (docXml == null) {
        throw Exception('Not a valid Word document format.');
      }

      final content = utf8.decode(docXml.content as List<int>, allowMalformed: true);
      final document = xml.XmlDocument.parse(content);
      final pNodes = document.findAllElements('w:p');
      final list = <DocParagraph>[];

      for (final p in pNodes) {
        final text = p.findAllElements('w:t').map((t) => t.innerText).join('').trim();
        if (text.isEmpty) continue;

        // Check if paragraph is a heading or list item
        final pStyle = p.findAllElements('w:pStyle').map((s) => s.getAttribute('w:val') ?? '').join('');
        final numPr = p.findAllElements('w:numPr').isNotEmpty;
        final isHeading = pStyle.toLowerCase().contains('heading') || pStyle.toLowerCase().contains('title');

        list.add(DocParagraph(
          text: text,
          isHeading: isHeading,
          isBullet: numPr,
        ));
      }

      if (list.isEmpty) {
        throw Exception('Document appears to be empty.');
      }

      setState(() {
        _paragraphs = list;
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
              const Icon(Icons.description_rounded, size: 56, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('Could not open Word document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 820),
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _paragraphs.map((p) {
                  if (p.isHeading) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 18.0, bottom: 8.0),
                      child: _buildHighlightedText(
                        p.text,
                        widget.searchQuery,
                        TextStyle(
                          fontSize: _fontSize + 4,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    );
                  }

                  if (p.isBullet) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0, right: 10.0),
                            child: Icon(Icons.circle, size: 6, color: Color(0xFF2563EB)),
                          ),
                          Expanded(
                            child: _buildHighlightedText(
                              p.text,
                              widget.searchQuery,
                              TextStyle(
                                fontSize: _fontSize,
                                height: 1.6,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: _buildHighlightedText(
                      p.text,
                      widget.searchQuery,
                      TextStyle(
                        fontSize: _fontSize,
                        height: 1.65,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style, {TextAlign textAlign = TextAlign.start}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty || !text.toLowerCase().contains(q)) {
      return SelectableText(text, style: style, textAlign: textAlign);
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
      textAlign: textAlign,
    );
  }
}
