import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recent_file.dart';
import '../utils/format_helper.dart';
import '../viewers/image_viewer.dart';
import '../viewers/spreadsheet_viewer.dart';
import '../viewers/presentation_viewer.dart';
import '../viewers/pdf_viewer.dart';
import '../viewers/docx_viewer.dart';
import '../viewers/code_text_viewer.dart';
import '../viewers/archive_viewer.dart';
import '../viewers/fallback_viewer.dart';

class ReaderScreen extends StatefulWidget {
  final String filePath;
  final Function(ThemeMode) onThemeChanged;
  final VoidCallback onClose;

  const ReaderScreen({
    super.key,
    required this.filePath,
    required this.onThemeChanged,
    required this.onClose,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const platform = MethodChannel('app.channel.shared.data');

  late String _currentPath;
  late FileCategory _category;
  bool _forceTextMode = false;

  // Immersive Mode
  bool _showBars = true;

  // Search
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Viewer keys to call context-sensitive actions
  final GlobalKey<ImageViewerState> _imageKey = GlobalKey<ImageViewerState>();
  final GlobalKey<SpreadsheetViewerState> _spreadsheetKey = GlobalKey<SpreadsheetViewerState>();
  final GlobalKey<PresentationViewerState> _presentationKey = GlobalKey<PresentationViewerState>();
  final GlobalKey<CustomPdfViewerState> _pdfKey = GlobalKey<CustomPdfViewerState>();
  final GlobalKey<DocxViewerState> _docxKey = GlobalKey<DocxViewerState>();
  final GlobalKey<CodeTextViewerState> _codeKey = GlobalKey<CodeTextViewerState>();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.filePath;
    _category = FormatHelper.getCategory(_currentPath);
    RecentFilesManager.addFile(_currentPath);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleBars() {
    setState(() {
      _showBars = !_showBars;
    });
  }

  Future<void> _shareFile() async {
    try {
      await platform.invokeMethod('shareFile', {'path': _currentPath});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sharing failed: $e')),
        );
      }
    }
  }

  void _showFileInfoSheet() async {
    final file = File(_currentPath);
    int size = 0;
    DateTime? modified;
    if (await file.exists()) {
      final stat = await file.stat();
      size = stat.size;
      modified = stat.modified;
    }

    String formattedSize = '$size B';
    if (size >= 1024 && size < 1024 * 1024) {
      formattedSize = '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size >= 1024 * 1024) {
      formattedSize = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FormatHelper.getCategoryColor(_category).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        FormatHelper.getCategoryIcon(_category),
                        color: FormatHelper.getCategoryColor(_category),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentPath.split(Platform.pathSeparator).last,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            FormatHelper.getCategoryLabel(_category),
                            style: TextStyle(fontSize: 12, color: FormatHelper.getCategoryColor(_category), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildInfoRow('File Size', formattedSize),
                if (modified != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Modified', modified.toString().split('.').first),
                ],
                const SizedBox(height: 12),
                _buildInfoRow('Full Path', _currentPath, isPath: true),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _shareFile();
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Document'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPath = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
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

  @override
  Widget build(BuildContext context) {
    final fileName = _currentPath.split(Platform.pathSeparator).last;
    final ext = FormatHelper.getExtension(_currentPath);
    final activeCategory = _forceTextMode ? FileCategory.codeText : _category;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _showBars ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_showBars,
            child: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              elevation: 0,
              scrolledUnderElevation: 2,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to Home',
                onPressed: widget.onClose,
              ),
              title: _isSearching
                  ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search in file...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              )
                  : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: FormatHelper.getCategoryColor(activeCategory).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ext.toUpperCase().isEmpty ? 'FILE' : ext.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: FormatHelper.getCategoryColor(activeCategory),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                if (!_isSearching && _supportsSearch(activeCategory))
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    tooltip: 'Search in document',
                    onPressed: () => setState(() => _isSearching = true),
                  ),
                if (_isSearching)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close search',
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  tooltip: 'File Details',
                  onPressed: _showFileInfoSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  tooltip: 'Share',
                  onPressed: _shareFile,
                ),
                PopupMenuButton<ThemeMode>(
                  icon: const Icon(Icons.brightness_6_rounded),
                  tooltip: 'Theme',
                  onSelected: widget.onThemeChanged,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: ThemeMode.light, child: Text('Light Theme')),
                    PopupMenuItem(value: ThemeMode.dark, child: Text('Dark Theme')),
                    PopupMenuItem(value: ThemeMode.system, child: Text('System Default')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildViewer(activeCategory),
            ),
            // Floating Bottom Action Capsule
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: AnimatedOpacity(
                opacity: _showBars ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_showBars,
                  child: _buildBottomDock(activeCategory),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _supportsSearch(FileCategory category) {
    return category == FileCategory.spreadsheet ||
        category == FileCategory.presentation ||
        category == FileCategory.word ||
        category == FileCategory.codeText;
  }

  Widget _buildViewer(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return ImageViewer(
          key: _imageKey,
          filePath: _currentPath,
          onTap: _toggleBars,
        );
      case FileCategory.spreadsheet:
        return SpreadsheetViewer(
          key: _spreadsheetKey,
          filePath: _currentPath,
          searchQuery: _searchQuery,
          onTap: _toggleBars,
        );
      case FileCategory.presentation:
        return PresentationViewer(
          key: _presentationKey,
          filePath: _currentPath,
          searchQuery: _searchQuery,
          onTap: _toggleBars,
        );
      case FileCategory.pdf:
        return CustomPdfViewer(
          key: _pdfKey,
          filePath: _currentPath,
          onTap: _toggleBars,
        );
      case FileCategory.word:
        return DocxViewer(
          key: _docxKey,
          filePath: _currentPath,
          searchQuery: _searchQuery,
          onTap: _toggleBars,
        );
      case FileCategory.codeText:
        return CodeTextViewer(
          key: _codeKey,
          filePath: _currentPath,
          searchQuery: _searchQuery,
          onTap: _toggleBars,
        );
      case FileCategory.archive:
        return ArchiveViewer(
          filePath: _currentPath,
          onTap: _toggleBars,
        );
      case FileCategory.other:
        return FallbackViewer(
          filePath: _currentPath,
          onOpenAsText: () => setState(() => _forceTextMode = true),
          onShare: _shareFile,
        );
    }
  }

  Widget _buildBottomDock(FileCategory category) {
    List<Widget> actions = [];

    switch (category) {
      case FileCategory.image:
        actions = [
          _buildDockButton(Icons.rotate_right_rounded, 'Rotate', () => _imageKey.currentState?.rotateClockwise()),
          _buildDockButton(Icons.flip_rounded, 'Flip', () => _imageKey.currentState?.flipHorizontal()),
          _buildDockButton(Icons.restart_alt_rounded, 'Reset', () => _imageKey.currentState?.resetZoom()),
          _buildDockButton(Icons.share_rounded, 'Share', _shareFile),
        ];
        break;

      case FileCategory.spreadsheet:
        actions = [
          _buildDockButton(Icons.remove_rounded, 'Zoom Out', () => _spreadsheetKey.currentState?.zoomOut()),
          _buildDockButton(Icons.add_rounded, 'Zoom In', () => _spreadsheetKey.currentState?.zoomIn()),
          _buildDockButton(Icons.table_chart_rounded, 'Toggle Header', () => _spreadsheetKey.currentState?.toggleFirstRowHeader()),
          _buildDockButton(Icons.share_rounded, 'Share', _shareFile),
        ];
        break;

      case FileCategory.presentation:
        // Presentation already has built-in floating pill controls, show mode and share in dock
        actions = [
          _buildDockButton(Icons.view_carousel_rounded, 'Deck / Cards', () => _presentationKey.currentState?.toggleViewMode()),
          _buildDockButton(Icons.share_rounded, 'Share', _shareFile),
        ];
        break;

      case FileCategory.pdf:
        actions = [
          _buildDockButton(Icons.find_in_page_rounded, 'Go to Page', () => _pdfKey.currentState?.showJumpDialog()),
          _buildDockButton(Icons.share_rounded, 'Share', _shareFile),
        ];
        break;

      case FileCategory.word:
        actions = [
          _buildDockButton(Icons.text_decrease_rounded, 'Smaller', () => _docxKey.currentState?.zoomOut()),
          _buildDockButton(Icons.text_increase_rounded, 'Larger', () => _docxKey.currentState?.zoomIn()),
          _buildDockButton(Icons.share_rounded, 'Share', _shareFile),
        ];
        break;

      case FileCategory.codeText:
        actions = [
          _buildDockButton(Icons.format_list_numbered_rounded, 'Line #s', () => _codeKey.currentState?.toggleLineNumbers()),
          _buildDockButton(Icons.wrap_text_rounded, 'Word Wrap', () => _codeKey.currentState?.toggleWordWrap()),
          _buildDockButton(Icons.edit_note_rounded, 'Edit/Save', () => _codeKey.currentState?.toggleEditMode()),
          _buildDockButton(Icons.copy_all_rounded, 'Copy All', () => _codeKey.currentState?.copyAllContent()),
          _buildDockButton(Icons.share_rounded, 'Share', _shareFile),
        ];
        break;

      case FileCategory.archive:
      case FileCategory.other:
        actions = [
          _buildDockButton(Icons.info_outline_rounded, 'Details', _showFileInfoSheet),
          _buildDockButton(Icons.share_rounded, 'Share', _shareFile),
        ];
        break;
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ),
      ),
    );
  }

  Widget _buildDockButton(IconData icon, String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
