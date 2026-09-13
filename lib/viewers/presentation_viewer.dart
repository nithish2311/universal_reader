import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;

class ParsedSlide {
  final String title;
  final List<String> bodyLines;
  ParsedSlide({required this.title, required this.bodyLines});
}

class PresentationViewer extends StatefulWidget {
  final String filePath;
  final String searchQuery;
  final VoidCallback? onTap;

  const PresentationViewer({
    super.key,
    required this.filePath,
    this.searchQuery = '',
    this.onTap,
  });

  @override
  State<PresentationViewer> createState() => PresentationViewerState();
}

class PresentationViewerState extends State<PresentationViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ParsedSlide> _slides = [];
  bool _isSlideshowMode = true;
  int _currentSlideIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadPptx();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PresentationViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadPptx();
    }
    if (widget.searchQuery.isNotEmpty && widget.searchQuery != oldWidget.searchQuery) {
      _jumpToFirstSearchMatch();
    }
  }

  void toggleViewMode() {
    setState(() {
      _isSlideshowMode = !_isSlideshowMode;
    });
  }

  void nextSlide() {
    if (_currentSlideIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void prevSlide() {
    if (_currentSlideIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void jumpToSlide(int index) {
    if (index >= 0 && index < _slides.length) {
      setState(() => _currentSlideIndex = index);
      if (_isSlideshowMode) {
        _pageController.jumpToPage(index);
      }
    }
  }

  void _jumpToFirstSearchMatch() {
    final q = widget.searchQuery.toLowerCase().trim();
    if (q.isEmpty) return;
    for (int i = 0; i < _slides.length; i++) {
      final s = _slides[i];
      if (s.title.toLowerCase().contains(q) || s.bodyLines.any((b) => b.toLowerCase().contains(q))) {
        jumpToSlide(i);
        break;
      }
    }
  }

  Future<void> _loadPptx() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _slides = [];
      _currentSlideIndex = 0;
    });

    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final List<ParsedSlide> parsedList = [];

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
          final List<String> body = [];

          for (final p in paragraphs) {
            final text = p.findAllElements('a:t').map((n) => n.innerText).join('').trim();
            if (text.isEmpty) continue;
            if (title.isEmpty) {
              title = text;
            } else {
              body.add(text);
            }
          }

          parsedList.add(ParsedSlide(
            title: title.isEmpty ? 'Untitled Slide' : title,
            bodyLines: body,
          ));
        }
      }

      if (parsedList.isEmpty) {
        throw Exception('No slides found in this presentation.');
      }

      setState(() {
        _slides = parsedList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showSlideGridModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Slides (${_slides.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _slides.length,
                  itemBuilder: (context, idx) {
                    final isCurrent = idx == _currentSlideIndex;
                    final slide = _slides[idx];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        jumpToSlide(idx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: Border.all(
                            color: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                            width: isCurrent ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Slide ${idx + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                slide.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, height: 1.2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
              const Icon(Icons.slideshow_rounded, size: 56, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('Could not load slides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: _isSlideshowMode ? _buildSlideshowView() : _buildContinuousView(),
        ),

        // Floating Slideshow Controls (Bottom Center)
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSlideshowMode) ...[
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _currentSlideIndex > 0 ? prevSlide : null,
                      tooltip: 'Previous Slide',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  InkWell(
                    onTap: _showSlideGridModal,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.grid_view_rounded, size: 14, color: Color(0xFFEA580C)),
                          const SizedBox(width: 6),
                          Text(
                            'Slide ${_currentSlideIndex + 1} of ${_slides.length}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isSlideshowMode) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _currentSlideIndex < _slides.length - 1 ? nextSlide : null,
                      tooltip: 'Next Slide',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(height: 20, width: 1, color: Theme.of(context).dividerColor),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_isSlideshowMode ? Icons.view_agenda_rounded : Icons.slideshow_rounded),
                    tooltip: _isSlideshowMode ? 'Switch to Continuous Scroll' : 'Switch to Slideshow Deck',
                    onPressed: toggleViewMode,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlideshowView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFE2E8F0),
      child: PageView.builder(
        controller: _pageController,
        itemCount: _slides.length,
        onPageChanged: (idx) {
          setState(() {
            _currentSlideIndex = idx;
          });
        },
        itemBuilder: (context, idx) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
              child: _buildSlideCard(_slides[idx], idx),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinuousView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFE2E8F0),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        itemCount: _slides.length,
        itemBuilder: (context, idx) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: _buildSlideCard(_slides[idx], idx),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlideCard(ParsedSlide slide, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 820, minHeight: 380),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Slide Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.slideshow_rounded, size: 14, color: Color(0xFFEA580C)),
                    const SizedBox(width: 5),
                    Text(
                      'Slide ${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${index + 1} / ${_slides.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Slide Title
          if (slide.title.isNotEmpty) ...[
            _buildHighlightedText(
              slide.title,
              widget.searchQuery,
              TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.2), thickness: 1.2),
            const SizedBox(height: 18),
          ],

          // Slide Body Bullets
          if (slide.bodyLines.isEmpty && slide.title.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  '(Title slide)',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
            ),

          ...slide.bodyLines.map((line) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0, right: 10.0),
                    child: Icon(Icons.circle, size: 7, color: Color(0xFFEA580C)),
                  ),
                  Expanded(
                    child: _buildHighlightedText(
                      line,
                      widget.searchQuery,
                      TextStyle(
                        fontSize: 15.5,
                        height: 1.55,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, TextStyle style, {TextAlign textAlign = TextAlign.start}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty || !text.toLowerCase().contains(q)) {
      return Text(text, style: style, textAlign: textAlign);
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
