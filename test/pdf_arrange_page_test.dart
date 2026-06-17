import 'dart:io';

import 'package:course_helper/core/performance/app_performance.dart';
import 'package:course_helper/models/pdf_arrange_models.dart';
import 'package:course_helper/models/file_tool_models.dart';
import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_library_store.dart';
import 'package:course_helper/pages/pdf_arrange_page.dart';
import 'package:course_helper/services/file_tool_history_store.dart';
import 'package:course_helper/services/pdf_arrange_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sourceFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('pdf_arrange_page_');
    sourceFile = File(p.join(tempDir.path, 'source.pdf'))
      ..writeAsStringSync('fake pdf');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      for (var i = 0; i < 5; i++) {
        try {
          await tempDir.delete(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  });

  testWidgets('initial page shows choose PDF empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PdfArrangePage(service: _FakeArrangeService())),
    );

    expect(find.text('PDF 页面编排'), findsOneWidget);
    expect(find.text('选择 PDF 开始页面编排'), findsOneWidget);
    expect(find.text('选择 PDF'), findsWidgets);
  });

  testWidgets('loads fake pages and supports delete restore and rotate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfArrangePage(
          service: _FakeArrangeService(),
          initialFile: sourceFile,
          outputDirectory: tempDir,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网格'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('原 1'), findsOneWidget);
    expect(find.text('原 2'), findsOneWidget);
    expect(find.textContaining('保留 2 页'), findsOneWidget);

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    expect(find.text('位置 1 · 原第 1 页'), findsOneWidget);

    await tester.tap(find.byTooltip('右旋 90°').first);
    await tester.pumpAndSettle();
    expect(find.text('旋转 90°'), findsOneWidget);

    await tester.tap(find.byTooltip('删除').first);
    await tester.pumpAndSettle();
    expect(find.text('导出时跳过'), findsOneWidget);
    expect(find.text('保留 1'), findsWidgets);

    await tester.tap(find.byTooltip('恢复').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('保留 2 页'), findsOneWidget);
  });

  testWidgets('switches to list view and shows drag handles', (tester) async {
    final service = _FakeArrangeService();
    await tester.pumpWidget(
      MaterialApp(
        home: PdfArrangePage(
          service: service,
          initialFile: sourceFile,
          outputDirectory: tempDir,
          historyStore: _FakeHistoryStore(),
          libraryStore: _FakeLibraryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

    expect(find.text('导出新 PDF'), findsOneWidget);
    final exportButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('pdf-arrange-export-button')),
    );
    expect(exportButton.onPressed, isNotNull);
  });

  testWidgets('multi-select duplicates page and undo restores previous count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfArrangePage(
          service: _FakeArrangeService(),
          initialFile: sourceFile,
          outputDirectory: tempDir,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('选中 1 页'), findsOneWidget);

    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(find.text('#3'), findsOneWidget);
    expect(find.textContaining('副本 1'), findsOneWidget);

    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(find.text('#3'), findsNothing);
    expect(find.textContaining('副本 0'), findsOneWidget);
  });

  testWidgets('range dialog selects current positions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PdfArrangePage(
          service: _FakeArrangeService(),
          initialFile: sourceFile,
          outputDirectory: tempDir,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('选择页面'));
    await tester.pumpAndSettle();
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('反选'), findsOneWidget);
    expect(find.text('奇数位'), findsOneWidget);
    expect(find.text('偶数位'), findsOneWidget);
    await tester.tap(find.text('页码范围'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1-2');
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();

    expect(find.textContaining('选中 2 页'), findsOneWidget);
  });

  testWidgets('wide layout shows side operation panel', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PdfArrangePage(
          service: _FakeArrangeService(),
          initialFile: sourceFile,
          outputDirectory: tempDir,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('操作面板'), findsOneWidget);
    expect(find.text('选择页面'), findsOneWidget);
    expect(find.text('导出新 PDF'), findsOneWidget);
  });
}

class _FakeArrangeService extends PdfArrangeService {
  _FakeArrangeService();

  bool exportCalled = false;

  @override
  Future<List<PdfArrangePageItem>> loadPages(File file) async {
    return const <PdfArrangePageItem>[
      PdfArrangePageItem(id: 'page-1', originalPageNumber: 1, currentIndex: 0),
      PdfArrangePageItem(id: 'page-2', originalPageNumber: 2, currentIndex: 1),
    ];
  }

  @override
  Future<List<PdfArrangePageItem>> renderThumbnails({
    required File file,
    required List<PdfArrangePageItem> items,
    double dpi = 60,
    void Function(int done, int total)? onProgress,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    onProgress?.call(items.length, items.length);
    return items;
  }

  @override
  Future<PdfArrangeExportResult> exportArrangedPdf({
    required File sourceFile,
    required List<PdfArrangePageItem> items,
    required Directory outputDirectory,
    Set<String>? selectedIds,
    PdfArrangeExportMode mode = PdfArrangeExportMode.keptPages,
  }) async {
    exportCalled = true;
    final output = File(p.join(outputDirectory.path, 'source_arranged.pdf'));
    await output.writeAsString('arranged');
    final selected = selectedIds ?? const <String>{};
    final kept = items
        .where((item) => !item.deleted)
        .where(
          (item) =>
              mode == PdfArrangeExportMode.keptPages ||
              selected.contains(item.id),
        )
        .length;
    return PdfArrangeExportResult(
      outputPath: output.path,
      keptCount: kept,
      deletedCount: items.length - kept,
      rotatedCount: items
          .where((item) => !item.deleted && item.hasRotation)
          .length,
      selectedOnly: mode == PdfArrangeExportMode.selectedPages,
    );
  }
}

class _FakeHistoryStore extends FileToolHistoryStore {
  _FakeHistoryStore();

  final List<FileToolHistoryRecord> records = <FileToolHistoryRecord>[];

  @override
  Future<void> append(FileToolHistoryRecord record) async {
    records.add(record);
  }
}

class _FakeLibraryStore extends MaterialLibraryStore {
  _FakeLibraryStore();

  @override
  Future<MaterialLibraryItem> upsertItem({
    required String path,
    required String name,
    required MaterialSourceType sourceType,
    required String sourceLabel,
    MaterialLibraryStatus status = MaterialLibraryStatus.inbox,
    List<String> tags = const <String>[],
    DateTime? importedAt,
  }) async {
    return MaterialLibraryItem(
      id: MaterialLibraryStore.idForPath(path),
      path: path,
      name: name,
      sourceType: sourceType,
      sourceLabel: sourceLabel,
      importedAt: importedAt ?? DateTime(2026, 1, 1),
      status: status,
      tags: tags,
    );
  }
}
