import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xl;
import 'package:csv/csv.dart';

class SheetData {
  final String name;
  final List<List<String>> rows;
  final int columnCount;

  SheetData({
    required this.name,
    required this.rows,
    required this.columnCount,
  });
}

class SpreadsheetViewer extends StatefulWidget {
  final String filePath;
  final String searchQuery;
  final VoidCallback? onTap;

  const SpreadsheetViewer({
    super.key,
    required this.filePath,
    this.searchQuery = '',
    this.onTap,
  });

  @override
  State<SpreadsheetViewer> createState() => SpreadsheetViewerState();
}

class SpreadsheetViewerState extends State<SpreadsheetViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SheetData> _sheets = [];
  int _selectedSheetIndex = 0;
  double _fontSize = 13.0;
  bool _useFirstRowAsHeader = true;

  @override
  void initState() {
    super.initState();
    _loadSpreadsheet();
  }

  @override
  void didUpdateWidget(covariant SpreadsheetViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadSpreadsheet();
    }
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

  void toggleFirstRowHeader() {
    setState(() {
      _useFirstRowAsHeader = !_useFirstRowAsHeader;
    });
  }

  Future<void> _loadSpreadsheet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sheets = [];
      _selectedSheetIndex = 0;
    });

    try {
      final ext = widget.filePath.split('.').last.toLowerCase();
      if (ext == 'csv' || ext == 'tsv') {
        final content = await File(widget.filePath).readAsString();
        final separator = ext == 'tsv' ? '\t' : ',';
        final converter = CsvToListConverter(
          fieldDelimiter: separator,
          eol: '\n',
          shouldParseNumbers: false,
        );
        final rawRows = converter.convert(content);
        final rows = <List<String>>[];
        int maxCols = 0;
        for (final r in rawRows) {
          final rowStr = r.map((cell) => cell.toString().trim()).toList();
          if (rowStr.length > maxCols) maxCols = rowStr.length;
          rows.add(rowStr);
        }
        _sheets = [
          SheetData(
            name: ext.toUpperCase(),
            rows: rows,
            columnCount: maxCols,
          ),
        ];
      } else {
        // Excel file (.xlsx or .xls)
        final bytes = await File(widget.filePath).readAsBytes();
        final excel = xl.Excel.decodeBytes(bytes);
        final loadedSheets = <SheetData>[];

        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;
          final rows = <List<String>>[];
          int maxCols = 0;

          for (final row in sheet.rows) {
            final rowList = <String>[];
            for (final cell in row) {
              rowList.add(cell?.value?.toString().trim() ?? '');
            }
            if (rowList.length > maxCols) maxCols = rowList.length;
            rows.add(rowList);
          }

          if (rows.isNotEmpty) {
            loadedSheets.add(SheetData(
              name: table,
              rows: rows,
              columnCount: maxCols,
            ));
          }
        }

        if (loadedSheets.isEmpty) {
          throw Exception('No readable sheets found in this Excel workbook.');
        }
        _sheets = loadedSheets;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showCellDetails(String value, int rowIdx, int colIdx, String colName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cell $colName${rowIdx + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      tooltip: 'Copy Cell Value',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cell content copied!'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 250),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      value.isEmpty ? '(Empty Cell)' : value,
                      style: TextStyle(
                        fontSize: 14,
                        color: value.isEmpty ? Colors.grey : null,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getColumnLetter(int colIndex) {
    String result = '';
    int index = colIndex;
    while (index >= 0) {
      result = String.fromCharCode((index % 26) + 65) + result;
      index = (index ~/ 26) - 1;
    }
    return result;
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
              const Icon(Icons.error_outline_rounded, size: 56, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text('Could not open spreadsheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_sheets.isEmpty) {
      return const Center(child: Text('Empty spreadsheet file.'));
    }

    final currentSheet = _sheets[_selectedSheetIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Sheet Selector Tabs (if more than 1 sheet)
        if (_sheets.length > 1)
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15))),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _sheets.length,
              itemBuilder: (context, idx) {
                final isSelected = idx == _selectedSheetIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(_sheets[idx].name),
                    onSelected: (val) {
                      setState(() {
                        _selectedSheetIndex = idx;
                      });
                    },
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                );
              },
            ),
          ),

        // Spreadsheet Stats & Info Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          child: Row(
            children: [
              Icon(Icons.table_rows_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '${currentSheet.rows.length} rows × ${currentSheet.columnCount} cols',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const Spacer(),
              InkWell(
                onTap: toggleFirstRowHeader,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _useFirstRowAsHeader ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      const Text('1st Row Header', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                tooltip: 'Decrease font size',
                onPressed: zoomOut,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Increase font size',
                onPressed: zoomIn,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Spreadsheet Data Grid
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTable(currentSheet, isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(SheetData sheet, bool isDark) {
    if (sheet.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('This sheet has no rows.'),
      );
    }

    final query = widget.searchQuery.toLowerCase().trim();
    final headerRow = _useFirstRowAsHeader ? sheet.rows.first : null;
    final dataRows = _useFirstRowAsHeader ? sheet.rows.skip(1).toList() : sheet.rows;

    final cellBorder = BorderSide(
      color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
      width: 0.8,
    );

    return DataTable(
      columnSpacing: 18,
      horizontalMargin: 12,
      headingRowHeight: 38,
      dataRowMinHeight: 32,
      dataRowMaxHeight: 48,
      border: TableBorder(
        top: cellBorder,
        bottom: cellBorder,
        left: cellBorder,
        right: cellBorder,
        horizontalInside: cellBorder,
        verticalInside: cellBorder,
      ),
      headingRowColor: WidgetStateProperty.all(
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      ),
      columns: [
        // Row Number Column Header
        DataColumn(
          label: Text(
            '#',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: _fontSize,
              color: Colors.grey,
            ),
          ),
        ),
        // Sheet Column Headers
        for (int c = 0; c < sheet.columnCount; c++)
          DataColumn(
            label: Text(
              headerRow != null && c < headerRow.length && headerRow[c].isNotEmpty
                  ? headerRow[c]
                  : _getColumnLetter(c),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _fontSize,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
      ],
      rows: [
        for (int r = 0; r < dataRows.length; r++)
          DataRow(
            color: WidgetStateProperty.resolveWith((states) {
              if (r % 2 == 1) {
                return isDark
                    ? const Color(0xFF131C2E)
                    : const Color(0xFFF8FAFC);
              }
              return null;
            }),
            cells: [
              // Row Index
              DataCell(
                Text(
                  '${_useFirstRowAsHeader ? r + 2 : r + 1}',
                  style: TextStyle(
                    fontSize: _fontSize * 0.85,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Cell Values
              for (int c = 0; c < sheet.columnCount; c++)
                DataCell(
                  _buildCellText(
                    c < dataRows[r].length ? dataRows[r][c] : '',
                    query,
                  ),
                  onTap: () {
                    final val = c < dataRows[r].length ? dataRows[r][c] : '';
                    _showCellDetails(val, r, c, _getColumnLetter(c));
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCellText(String text, String query) {
    if (query.isNotEmpty && text.toLowerCase().contains(query)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amberAccent.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(fontSize: _fontSize),
      overflow: TextOverflow.ellipsis,
    );
  }
}
