import 'dart:io';

import 'package:course_helper/models/file_output_manager_models.dart';
import 'package:course_helper/core/performance/app_performance.dart';
import 'package:course_helper/models/file_tool_models.dart';
import 'package:course_helper/pages/file_output_manager_page.dart';
import 'package:course_helper/services/file_output_manager_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOutputManagerService extends FileOutputManagerService {
  _FakeOutputManagerService(this.items);

  List<FileOutputItem> items;
  final List<String> hiddenPaths = <String>[];
  final List<String> libraryPaths = <String>[];

  @override
  Future<List<FileOutputItem>> loadOutputs({
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async => items;

  @override
  Future<void> removeFromHistory(Iterable<String> paths) async {
    hiddenPaths.addAll(paths);
    final hidden = paths.toSet();
    items = items.where((item) => !hidden.contains(item.path)).toList();
  }

  @override
  Future<int> addToMaterialLibrary(Iterable<FileOutputItem> items) async {
    final existing = items.where((item) => item.exists).toList();
    libraryPaths.addAll(existing.map((item) => item.path));
    return existing.length;
  }

  @override
  Future<int> deleteOutputs(Iterable<FileOutputItem> items) async => 0;
}

void main() {
  FileOutputItem item({
    required String id,
    required String name,
    required String path,
    required FileOutputStatus status,
    bool exists = true,
    bool hasHistory = true,
  }) {
    return FileOutputItem(
      id: id,
      path: path,
      name: name,
      scope: FileToolHistoryScope.file,
      sourceLabel: '文件工具输出',
      toolName: 'ZIP 打包',
      timestamp: DateTime(2026, 6, 7, 12),
      exists: exists,
      isDirectory: false,
      sizeBytes: exists ? 128 : 0,
      status: status,
      hasHistory: hasHistory,
    );
  }

  testWidgets('renders empty state, summary, filter, and search', (tester) async {
    await _pumpPage(
      tester,
      FileOutputManagerPage(
        service: _FakeOutputManagerService(<FileOutputItem>[]),
      ),
    );

    expect(find.byKey(const ValueKey('outputManagerPage')), findsOneWidget);
    expect(find.byKey(const ValueKey('outputManagerSearchField')), findsOneWidget);
    expect(find.byKey(const ValueKey('outputManagerFilter')), findsOneWidget);
    expect(find.byKey(const ValueKey('outputManagerEmptyState')), findsOneWidget);
  });

  testWidgets('available output shows item actions', (tester) async {
    final service = _FakeOutputManagerService(<FileOutputItem>[
      item(
        id: 'one',
        name: 'archive.zip',
        path: pForTest('archive.zip'),
        status: FileOutputStatus.available,
      ),
    ]);

    await _pumpPage(tester, FileOutputManagerPage(service: service));

    expect(find.text('archive.zip'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('outputItemMenu:one')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('outputActionPreview:one')), findsOneWidget);
    expect(find.byKey(const ValueKey('outputActionShare:one')), findsOneWidget);
    expect(find.byKey(const ValueKey('outputActionLibrary:one')), findsOneWidget);
    expect(find.byKey(const ValueKey('outputActionDelete:one')), findsOneWidget);
  });

  testWidgets('missing output offers remove from history', (tester) async {
    final service = _FakeOutputManagerService(<FileOutputItem>[
      item(
        id: 'missing',
        name: 'missing.pdf',
        path: pForTest('missing.pdf'),
        status: FileOutputStatus.missing,
        exists: false,
      ),
    ]);

    await _pumpPage(tester, FileOutputManagerPage(service: service));

    await tester.tap(find.byKey(const ValueKey('outputItemMenu:missing')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('outputActionHide:missing')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('outputActionPreview:missing')),
      findsNothing,
    );
  });

  testWidgets('selection bar can hide selected history', (tester) async {
    final service = _FakeOutputManagerService(<FileOutputItem>[
      item(
        id: 'one',
        name: 'one.txt',
        path: pForTest('one.txt'),
        status: FileOutputStatus.available,
      ),
    ]);

    await _pumpPage(tester, FileOutputManagerPage(service: service));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.byKey(const ValueKey('outputManagerSelectionBar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('outputSelectionBatchMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('outputBatchHideHistory')));
    await tester.pumpAndSettle();

    expect(service.hiddenPaths, contains(pForTest('one.txt')));
  });
}

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

String pForTest(String name) {
  return '${Directory.systemTemp.path}${Platform.pathSeparator}$name';
}
