import 'package:flutter/material.dart';

enum FileCategory {
  image,
  spreadsheet,
  presentation,
  pdf,
  word,
  codeText,
  archive,
  other,
}

class FormatHelper {
  static const Set<String> imageExtensions = {
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'ico', 'svg', 'heic'
  };

  static const Set<String> spreadsheetExtensions = {
    'xlsx', 'xls', 'csv', 'tsv'
  };

  static const Set<String> presentationExtensions = {
    'pptx', 'ppt'
  };

  static const Set<String> pdfExtensions = {
    'pdf'
  };

  static const Set<String> wordExtensions = {
    'docx', 'doc', 'rtf', 'odt'
  };

  static const Set<String> codeTextExtensions = {
    'txt', 'md', 'markdown', 'json', 'xml', 'html', 'htm', 'css', 'js', 'ts',
    'dart', 'py', 'java', 'kt', 'kts', 'c', 'cpp', 'h', 'hpp', 'cs', 'sh',
    'bash', 'yaml', 'yml', 'ini', 'env', 'sql', 'log', 'properties', 'gradle',
    'swift', 'go', 'rs', 'rb', 'php'
  };

  static const Set<String> archiveExtensions = {
    'zip', 'jar', 'apk'
  };

  static FileCategory getCategory(String path) {
    final ext = getExtension(path);
    if (imageExtensions.contains(ext)) return FileCategory.image;
    if (spreadsheetExtensions.contains(ext)) return FileCategory.spreadsheet;
    if (presentationExtensions.contains(ext)) return FileCategory.presentation;
    if (pdfExtensions.contains(ext)) return FileCategory.pdf;
    if (wordExtensions.contains(ext)) return FileCategory.word;
    if (codeTextExtensions.contains(ext)) return FileCategory.codeText;
    if (archiveExtensions.contains(ext)) return FileCategory.archive;
    return FileCategory.other;
  }

  static String getExtension(String path) {
    final cleanPath = path.split('?').first;
    if (!cleanPath.contains('.')) return '';
    return cleanPath.split('.').last.toLowerCase();
  }

  static String getCategoryLabel(FileCategory cat) {
    switch (cat) {
      case FileCategory.image:
        return 'Image';
      case FileCategory.spreadsheet:
        return 'Spreadsheet';
      case FileCategory.presentation:
        return 'Presentation';
      case FileCategory.pdf:
        return 'PDF Document';
      case FileCategory.word:
        return 'Word Document';
      case FileCategory.codeText:
        return 'Code & Text';
      case FileCategory.archive:
        return 'Archive';
      case FileCategory.other:
        return 'Document';
    }
  }

  static IconData getCategoryIcon(FileCategory cat) {
    switch (cat) {
      case FileCategory.image:
        return Icons.image_rounded;
      case FileCategory.spreadsheet:
        return Icons.table_chart_rounded;
      case FileCategory.presentation:
        return Icons.slideshow_rounded;
      case FileCategory.pdf:
        return Icons.picture_as_pdf_rounded;
      case FileCategory.word:
        return Icons.description_rounded;
      case FileCategory.codeText:
        return Icons.code_rounded;
      case FileCategory.archive:
        return Icons.folder_zip_rounded;
      case FileCategory.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color getCategoryColor(FileCategory cat) {
    switch (cat) {
      case FileCategory.image:
        return const Color(0xFF0284C7); // Sky blue
      case FileCategory.spreadsheet:
        return const Color(0xFF16A34A); // Emerald green
      case FileCategory.presentation:
        return const Color(0xFFEA580C); // Warm orange
      case FileCategory.pdf:
        return const Color(0xFFDC2626); // Crimson red
      case FileCategory.word:
        return const Color(0xFF2563EB); // Royal blue
      case FileCategory.codeText:
        return const Color(0xFF7C3AED); // Purple
      case FileCategory.archive:
        return const Color(0xFFD97706); // Amber
      case FileCategory.other:
        return const Color(0xFF64748B); // Slate
    }
  }
}
