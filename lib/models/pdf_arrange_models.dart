import 'dart:typed_data';

class PdfArrangePageItem {
  const PdfArrangePageItem({
    required this.id,
    required this.originalPageNumber,
    required this.currentIndex,
    this.thumbnailBytes,
    this.rotationDegrees = 0,
    this.deleted = false,
  });

  final String id;
  final int originalPageNumber;
  final int currentIndex;
  final Uint8List? thumbnailBytes;
  final int rotationDegrees;
  final bool deleted;

  bool get hasRotation => normalizedRotationDegrees != 0;

  int get normalizedRotationDegrees {
    final normalized = rotationDegrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  PdfArrangePageItem copyWith({
    String? id,
    int? currentIndex,
    Uint8List? thumbnailBytes,
    int? rotationDegrees,
    bool? deleted,
  }) {
    return PdfArrangePageItem(
      id: id ?? this.id,
      originalPageNumber: originalPageNumber,
      currentIndex: currentIndex ?? this.currentIndex,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      deleted: deleted ?? this.deleted,
    );
  }
}

enum PdfArrangeLayoutMode { grid, list }

enum PdfArrangeExportMode { keptPages, selectedPages }

class PdfArrangeExportResult {
  const PdfArrangeExportResult({
    required this.outputPath,
    required this.keptCount,
    required this.deletedCount,
    required this.rotatedCount,
    this.duplicateCount = 0,
    this.selectedOnly = false,
  });

  final String outputPath;
  final int keptCount;
  final int deletedCount;
  final int rotatedCount;
  final int duplicateCount;
  final bool selectedOnly;
}

class PdfArrangeException implements Exception {
  const PdfArrangeException(this.message);

  final String message;

  @override
  String toString() => message;
}
