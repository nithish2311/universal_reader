import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  runApp(const UniversalReaderApp());
}

class UniversalReaderApp extends StatefulWidget {
  const UniversalReaderApp({super.key});

  @override
  State<UniversalReaderApp> createState() => _UniversalReaderAppState();
}

class _UniversalReaderAppState extends State<UniversalReaderApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Universal Reader',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F3F6),
        colorSchemeSeed: const Color(0xFF2B579A),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorSchemeSeed: const Color(0xFF2B579A),
      ),
      themeMode: _themeMode,
      home: ReaderHomePage(onThemeChanged: changeTheme),
    );
  }
}

class ReaderHomePage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const ReaderHomePage({super.key, required this.onThemeChanged});

  @override
  State<ReaderHomePage> createState() => _ReaderHomePageState();
}

class _ReaderHomePageState extends State<ReaderHomePage> {
  static const platform = MethodChannel('app.channel.shared.data');
  String? _filePath;

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Orientation state
  bool _isLandscape = false;

  // Edit Mode state
  bool _isEditing = false;
  final TextEditingController _editController = TextEditingController();

  // PPT slides state
  List<ParsedSlide> _slides = [];
  bool _isLoadingPpt = false;
  final ScrollController _pptScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkSharedFile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _editController.dispose();
    _pptScrollController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _checkSharedFile() async {
    try {
      final String? path = await platform.invokeMethod('getSharedFilePath');
      if (path != null) {
        _loadFile(path);
      }
    } on PlatformException catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        _loadFile(result.files.single.path!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File selection failed: $e')),
      );
    }
  }

  void _loadFile(String path) async {
    setState(() {
      _filePath = path;
      _isEditing = false;
      _searchQuery = '';
      _isSearching = false;
      _slides = [];
    });

    final ext = path.toLowerCase().split('.').last;
    if (ext == 'pptx') {
      setState(() => _isLoadingPpt = true);
      final parsed = await _parsePptxSlides(path);
      setState(() {
        _slides = parsed;
        _isLoadingPpt = false;
      });
    }
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  Future<void> _shareCurrentFile() async {
    if (_filePath == null) return;
    try {
      await platform.invokeMethod('shareFile', {'path': _filePath!});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share error: $e')),
      );
    }
  }

  Future<void> _saveEditedFile() async {
    if (_filePath == null) return;
    try {
      final file = File(_filePath!);
      await file.writeAsString(_editController.text);
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String fileName = _filePath != null
        ? _filePath!.split(Platform.pathSeparator).last
        : "Universal Reader";

    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            hintText: "Search in document...",
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase().trim();
            });
          },
        )
            : Text(
          fileName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_filePath != null && !_isEditing) ...[
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              tooltip: _isSearching ? "Close Search" : "Search Word",
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchQuery = '';
                    _searchController.clear();
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(_isLandscape ? Icons.screen_lock_portrait_rounded : Icons.screen_rotation_rounded),
              tooltip: "Rotate Screen",
              onPressed: _toggleOrientation,
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: "Share File",
              onPressed: _shareCurrentFile,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: "Close File",
              onPressed: () => setState(() => _filePath = null),
            ),
          ],
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.green),
              tooltip: "Save",
              onPressed: _saveEditedFile,
            ),
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: "Discard",
              onPressed: () => setState(() => _isEditing = false),
            ),
          ],
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6_rounded),
            tooltip: "Theme",
            onSelected: widget.onThemeChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.light, child: Text("Light Mode")),
              PopupMenuItem(value: ThemeMode.dark, child: Text("Dark Mode")),
              PopupMenuItem(value: ThemeMode.system, child: Text("System Default")),
            ],
          ),
        ],
      ),
      body: _filePath == null
          ? _buildEmptyState()
          : _isEditing
          ? _buildEditorView()
          : _buildUniversalViewer(_filePath!),
      bottomNavigationBar: _filePath != null && !_isEditing ? _buildBottomToolbar() : null,
      floatingActionButton: _filePath == null
          ? FloatingActionButton.extended(
        onPressed: _pickFile,
        icon: const Icon(Icons.file_open_rounded),
        label: const Text("Open Document"),
      )
          : null,
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
      ),
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomActionItem(
            icon: Icons.screen_rotation_rounded,
            label: "Rotate",
            onTap: _toggleOrientation,
          ),
          _BottomActionItem(
            icon: Icons.search_rounded,
            label: "Search",
            onTap: () => setState(() => _isSearching = true),
          ),
          _BottomActionItem(
            icon: Icons.edit_note_rounded,
            label: "Edit",
            onTap: () async {
              final ext = _filePath!.toLowerCase().split('.').last;
              if (ext == 'pdf') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF direct editing is read-only')),
                );
                return;
              }
              String content = "";
              if (ext == 'docx') {
                final paras = await _parseDocxParagraphs(_filePath!);
                content = paras.join('\n\n');
              } else if (ext == 'pptx') {
                content = _slides.map((s) => "### ${s.title}\n${s.bodyLines.join('\n')}").join('\n\n---\n\n');
              } else {
                content = await File(_filePath!).readAsString();
              }
              _editController.text = content;
              setState(() => _isEditing = true);
            },
          ),
          _BottomActionItem(
            icon: Icons.share_rounded,
            label: "Share",
            onTap: _shareCurrentFile,
          ),
        ],
      ),
    );
  }

  Widget _buildEditorView() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _editController,
        maxLines: null,
        expands: true,
        style: const TextStyle(fontSize: 15, height: 1.5, fontFamily: 'monospace'),
        decoration: const InputDecoration(
          hintText: "Edit content here...",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Universal Document Reader",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Open PDFs, Presentations, Word files, and Code with vertical scroll and search.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text("Browse Document"),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniversalViewer(String path) {
    final cleanPath = path.split('?').first;
    final ext = cleanPath.contains('.') ? cleanPath.toLowerCase().split('.').last : '';

    // 1. PDF Viewer
    if (ext == 'pdf') {
      final pdfPinchController = PdfControllerPinch(
        document: PdfDocument.openFile(path),
      );
      return Container(
        color: const Color(0xFF525659),
        child: PdfViewPinch(controller: pdfPinchController),
      );
    }

    // 2. PowerPoint Slide Viewer (Vertical Continuous Flow - Top to Bottom)
    if (ext == 'pptx') {
      if (_isLoadingPpt) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_slides.isEmpty) {
        return const Center(child: Text("No slides found in this presentation."));
      }

      final displaySlides = _searchQuery.isEmpty
          ? _slides
          : _slides.where((s) =>
      s.title.toLowerCase().contains(_searchQuery) ||
          s.bodyLines.any((b) => b.toLowerCase().contains(_searchQuery))).toList();

      if (displaySlides.isEmpty) {
        return const Center(child: Text("No matching slides found."));
      }

      return Container(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141414) : const Color(0xFFE2E8F0),
        child: ListView.builder(
          controller: _pptScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
          itemCount: displaySlides.length,
          itemBuilder: (context, index) {
            final slide = displaySlides[index];
            return Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 800),
                margin: const EdgeInsets.only(bottom: 20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Slide Number Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.slideshow_rounded, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              "Slide ${index + 1}",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "${index + 1} / ${displaySlides.length}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (slide.title.isNotEmpty) ...[
                      _buildHighlightedText(
                        slide.title,
                        _searchQuery,
                        const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFE2E8F0), thickness: 1.2, height: 1),
                      const SizedBox(height: 14),
                    ],
                    // Body text lines
                    ...slide.bodyLines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "•  ",
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: _buildHighlightedText(
                                line,
                                _searchQuery,
                                const TextStyle(
                                  fontSize: 14.5,
                                  color: Color(0xFF334155),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // 3. Word Document (.docx)
    if (ext == 'docx') {
      return FutureBuilder<List<String>>(
        future: _parseDocxParagraphs(path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(child: Text("Error reading document: ${snapshot.error}"));
          }

          final paragraphs = snapshot.data!;
          return Container(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF141414) : const Color(0xFFE2E8F0),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 36.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: paragraphs.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildHighlightedText(
                          p,
                          _searchQuery,
                          const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF222222),
                            height: 1.6,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // 4. Code / Markdown / Text Viewer
    return FutureBuilder<String>(
      future: File(path).readAsString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Preview unsupported: $path"));
        }
        if (ext == 'md') {
          return Markdown(data: snapshot.data ?? "");
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _buildHighlightedText(
            snapshot.data ?? "",
            _searchQuery,
            const TextStyle(fontSize: 14, fontFamily: 'monospace', height: 1.5),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style, {TextAlign textAlign = TextAlign.start}) {
    if (query.isEmpty || !text.toLowerCase().contains(query)) {
      return Text(text, style: style, textAlign: textAlign);
    }

    final spans = <TextSpan>[];
    int start = 0;
    final lower = text.toLowerCase();

    while (start < text.length) {
      final index = lower.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: Colors.amberAccent,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + query.length;
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
    );
  }

  Future<List<ParsedSlide>> _parsePptxSlides(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final List<ParsedSlide> slides = [];

    final slideFiles = archive.files
        .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList();

    slideFiles.sort((a, b) {
      final numA = int.tryParse(RegExp(r'\d+').firstMatch(a.name)?.group(0) ?? '0') ?? 0;
      final numB = int.tryParse(RegExp(r'\d+').firstMatch(b.name)?.group(0) ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    for (final file in slideFiles) {
      if (file.content is List<int>) {
        final content = utf8.decode(file.content as List<int>, allowMalformed: true);
        final document = xml.XmlDocument.parse(content);

        final paragraphs = document.findAllElements('a:p');
        String title = '';
        List<String> bodyLines = [];

        for (final p in paragraphs) {
          final text = p.findAllElements('a:t').map((node) => node.innerText).join('').trim();
          if (text.isEmpty) continue;

          if (title.isEmpty) {
            title = text;
          } else {
            bodyLines.add(text);
          }
        }

        if (title.isNotEmpty || bodyLines.isNotEmpty) {
          slides.add(ParsedSlide(title: title, bodyLines: bodyLines));
        }
      }
    }
    return slides;
  }

  Future<List<String>> _parseDocxParagraphs(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docXml = archive.findFile('word/document.xml');
    if (docXml == null) return [];

    final content = utf8.decode(docXml.content as List<int>, allowMalformed: true);
    final document = xml.XmlDocument.parse(content);

    return document
        .findAllElements('w:p')
        .map((p) => p.findAllElements('w:t').map((t) => t.innerText).join(''))
        .where((text) => text.trim().isNotEmpty)
        .toList();
  }
}

class _BottomActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomActionItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class ParsedSlide {
  final String title;
  final List<String> bodyLines;
  ParsedSlide({required this.title, required this.bodyLines});
}