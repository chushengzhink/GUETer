import '../session/app_settings.dart';
import 'reading_catalog.dart';

class ReadingProgressSnapshot {
  const ReadingProgressSnapshot({
    required this.nightMode,
    required this.bookPageMap,
    required this.bookLastOpenMap,
  });

  final bool nightMode;
  final Map<String, int> bookPageMap;
  final Map<String, DateTime> bookLastOpenMap;
}

class ReadingProgressStore {
  String _bookKeySuffix(String assetPath) => Uri.encodeComponent(assetPath);

  String _bookLastPageKey(String assetPath) =>
      '${AppSettings.readingLastPageKey}_${_bookKeySuffix(assetPath)}';

  String _bookLastOpenAtKey(String assetPath) =>
      '${AppSettings.readingLastOpenAtKey}_${_bookKeySuffix(assetPath)}';

  Future<String> _loadBookValue(
    String primaryKey, {
    required String fallbackKey,
    required bool fallbackEnabled,
    String defaultValue = '',
  }) async {
    var value = await AppSettings.getString(primaryKey, defaultValue);
    if (value.isEmpty && fallbackEnabled) {
      value = await AppSettings.getString(fallbackKey, defaultValue);
    }
    return value;
  }

  Future<ReadingProgressSnapshot> loadState(List<ReadingBookEntry> books) async {
    final bookPageMap = <String, int>{};
    final bookLastOpenMap = <String, DateTime>{};
    final nightMode = await AppSettings.getBool(
      AppSettings.readingNightModeKey,
      false,
    );

    final primaryAssetPath = books.isNotEmpty ? books.first.assetPath : '';
    for (final book in books) {
      final isPrimary = book.assetPath == primaryAssetPath;

      final pageRaw = await _loadBookValue(
        _bookLastPageKey(book.assetPath),
        fallbackKey: AppSettings.readingLastPageKey,
        fallbackEnabled: isPrimary,
        defaultValue: '1',
      );
      final page = int.tryParse(pageRaw);
      if (page != null && page > 0) {
        bookPageMap[book.assetPath] = page;
      }

      final openRaw = await _loadBookValue(
        _bookLastOpenAtKey(book.assetPath),
        fallbackKey: AppSettings.readingLastOpenAtKey,
        fallbackEnabled: isPrimary,
      );
      final openMillis = int.tryParse(openRaw);
      if (openMillis != null) {
        bookLastOpenMap[book.assetPath] =
            DateTime.fromMillisecondsSinceEpoch(openMillis);
      }
    }

    return ReadingProgressSnapshot(
      nightMode: nightMode,
      bookPageMap: bookPageMap,
      bookLastOpenMap: bookLastOpenMap,
    );
  }

  Future<void> saveLastPage({
    required String assetPath,
    required int page,
    required bool writeLegacy,
  }) async {
    await AppSettings.setString(_bookLastPageKey(assetPath), page.toString());
    if (writeLegacy) {
      await AppSettings.setString(AppSettings.readingLastPageKey, page.toString());
    }
  }

  Future<void> saveLastOpenedAt({
    required String assetPath,
    required DateTime openedAt,
    required bool writeLegacy,
  }) async {
    final value = openedAt.millisecondsSinceEpoch.toString();
    await AppSettings.setString(_bookLastOpenAtKey(assetPath), value);
    if (writeLegacy) {
      await AppSettings.setString(AppSettings.readingLastOpenAtKey, value);
    }
  }

  Future<void> saveNightMode(bool value) {
    return AppSettings.setBool(AppSettings.readingNightModeKey, value);
  }
}