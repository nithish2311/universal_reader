import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class CustomPdfViewer extends StatefulWidget {
  final String filePath;
  final VoidCallback? onTap;

  const CustomPdfViewer({
    super.key,
    required this.filePath,
    this.onTap,
  });

  @override
  State<CustomPdfViewer> createState() => CustomPdfViewerState();
}

class CustomPdfViewerState extends State<CustomPdfViewer> {
  late PdfControllerPinch _pdfController;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  void _initPdf() {
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void didUpdateWidget(covariant CustomPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _pdfController.dispose();
      _initPdf();
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void jumpToPage(int page) {
    if (page >= 1 && page <= _totalPages) {
      _pdfController.jumpToPage(page);
    }
  }

  void showJumpDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Go to Page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Page Number (1 - $_totalPages)',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(controller.text.trim());
                if (page != null && page >= 1 && page <= _totalPages) {
                  jumpToPage(page);
                  Navigator.pop(context);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: Container(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF4A4E54),
            child: PdfViewPinch(
              controller: _pdfController,
              onDocumentLoaded: (doc) {
                setState(() {
                  _totalPages = doc.pagesCount;
                  _isReady = true;
                });
              },
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
            ),
          ),
        ),

        // Floating Page Counter Pill (Bottom Center)
        if (_isReady && _totalPages > 0)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: InkWell(
                onTap: showJumpDialog,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Text(
                        'Page $_currentPage of $_totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
