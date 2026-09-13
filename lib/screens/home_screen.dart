import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/recent_file.dart';
import '../utils/format_helper.dart';

class HomeScreen extends StatefulWidget {
  final Function(String) onFileSelected;
  final Function(ThemeMode) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.onFileSelected,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RecentFile> _recentFiles = [];
  bool _isLoadingRecents = true;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final list = await RecentFilesManager.loadRecentFiles();
    if (mounted) {
      setState(() {
        _recentFiles = list;
        _isLoadingRecents = false;
      });
    }
  }

  Future<void> _pickFile([FileType type = FileType.any, List<String>? allowedExtensions]) async {
    try {
      FilePickerResult? result;
      if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: allowedExtensions,
        );
      } else {
        result = await FilePicker.platform.pickFiles(type: type);
      }

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        widget.onFileSelected(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecents = _filterQuery.isEmpty
        ? _recentFiles
        : _recentFiles.where((f) => f.name.toLowerCase().contains(_filterQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Universal Reader',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  'All documents, images & data in one place',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6_rounded),
            tooltip: 'Change Theme',
            onSelected: widget.onThemeChanged,
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
              PopupMenuItem(value: ThemeMode.system, child: Text('System Default')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecents,
        child: CustomScrollView(
          slivers: [
            // Quick Categories Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Browse by Format',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFormatCard(
                            icon: Icons.image_rounded,
                            label: 'Images',
                            sublabel: 'PNG, JPG, WEBP',
                            color: const Color(0xFF0284C7),
                            onTap: () => _pickFile(FileType.image),
                          ),
                          _buildFormatCard(
                            icon: Icons.table_chart_rounded,
                            label: 'Spreadsheets',
                            sublabel: 'Excel & CSV',
                            color: const Color(0xFF16A34A),
                            onTap: () => _pickFile(FileType.custom, ['xlsx', 'xls', 'csv', 'tsv']),
                          ),
                          _buildFormatCard(
                            icon: Icons.slideshow_rounded,
                            label: 'Slides',
                            sublabel: 'PPTX, PPT',
                            color: const Color(0xFFEA580C),
                            onTap: () => _pickFile(FileType.custom, ['pptx', 'ppt']),
                          ),
                          _buildFormatCard(
                            icon: Icons.picture_as_pdf_rounded,
                            label: 'PDFs',
                            sublabel: 'Read & Zoom',
                            color: const Color(0xFFDC2626),
                            onTap: () => _pickFile(FileType.custom, ['pdf']),
                          ),
                          _buildFormatCard(
                            icon: Icons.description_rounded,
                            label: 'Word / Docs',
                            sublabel: 'DOCX, RTF',
                            color: const Color(0xFF2563EB),
                            onTap: () => _pickFile(FileType.custom, ['docx', 'doc', 'rtf']),
                          ),
                          _buildFormatCard(
                            icon: Icons.code_rounded,
                            label: 'Code & Text',
                            sublabel: 'TXT, MD, JSON',
                            color: const Color(0xFF7C3AED),
                            onTap: () => _pickFile(FileType.custom, [
                              'txt', 'md', 'json', 'xml', 'html', 'css', 'js', 'ts', 'dart', 'py', 'java', 'kt', 'c', 'cpp', 'yaml', 'sql', 'log'
                            ]),
                          ),
                          _buildFormatCard(
                            icon: Icons.folder_zip_rounded,
                            label: 'Archives',
                            sublabel: 'ZIP, JAR',
                            color: const Color(0xFFD97706),
                            onTap: () => _pickFile(FileType.custom, ['zip', 'jar', 'apk']),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recent Documents Header & Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    const Text(
                      'Recent Documents',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (_recentFiles.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_recentFiles.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (_recentFiles.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          await RecentFilesManager.clearAll();
                          _loadRecents();
                        },
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ),

            // Recents Filter Search Bar
            if (_recentFiles.length > 3)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Filter recent files...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) {
                        setState(() => _filterQuery = val.trim());
                      },
                    ),
                  ),
                ),
              ),

            // Recents List or Empty State
            if (_isLoadingRecents)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_recentFiles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else if (filteredRecents.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('No files match "$_filterQuery"', style: const TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                      final item = filteredRecents[idx];
                      return _buildRecentFileTile(item);
                    },
                    childCount: filteredRecents.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickFile(FileType.any),
        icon: const Icon(Icons.folder_open_rounded),
        label: const Text('Browse Files'),
        elevation: 4,
      ),
    );
  }

  Widget _buildFormatCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 125,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFileTile(RecentFile file) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = FormatHelper.getCategory(file.path);
    final color = FormatHelper.getCategoryColor(cat);
    final icon = FormatHelper.getCategoryIcon(cat);

    return Dismissible(
      key: Key(file.path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) async {
        await RecentFilesManager.removeFile(file.path);
        _loadRecents();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            file.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  file.extension.toUpperCase().isEmpty ? 'FILE' : file.extension.toUpperCase(),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                file.formattedSize,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          onTap: () => widget.onFileSelected(file.path),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_special_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Recent Documents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap below or select any format above to open and view photos, spreadsheets, slides, PDFs, and code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _pickFile(FileType.any),
              icon: const Icon(Icons.file_open_rounded, size: 18),
              label: const Text('Open Any Document'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
