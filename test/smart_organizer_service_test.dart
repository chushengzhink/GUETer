import 'dart:io';

import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_index_service.dart';
import 'package:course_helper/materials/material_library_store.dart';
import 'package:course_helper/models/file_output_manager_models.dart';
import 'package:course_helper/core/performance/app_performance.dart';
import 'package:course_helper/plugins/plugin_store.dart';
import 'package:course_helper/services/file_output_manager_service.dart';
import 'package:course_helper/smart/smart_organizer_service.dart';
import 'package:course_helper/study/study_card_models.dart';
import 'package:course_helper/study/study_card_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('smart_organizer_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates todo, material, review and output insights', () async {
    final materialFile = File(p.join(tempDir.path, '期末考试重点.pdf'));
    await materialFile.writeAsString('final exam notes');
    final largeOutput = File(p.join(tempDir.path, 'export.pdf'));
    await largeOutput.writeAsBytes(List<int>.filled(64 * 1024, 1));

    final materialStore = MaterialLibraryStore();
    await materialStore.upsertItem(
      path: materialFile.path,
      name: '期末考试重点.pdf',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '课程资料',
      importedAt: DateTime(2026, 6, 8),
    );

    final studyStore = StudyCardStore();
    final dueCard = await studyStore.addCard(
      front: '今日复习',
      back: '',
      sourceFileName: 'missing.pdf',
      sourcePath: p.join(tempDir.path, 'missing.pdf'),
    );
    await studyStore.reviewCard(
      dueCard.id,
      StudyReviewRating.forgot,
      now: DateTime(2026, 6, 8, 9),
    );

    final service = SmartOrganizerService(
      materialLibraryStore: materialStore,
      materialIndexService: _FakeMaterialIndexService(),
      studyCardStore: studyStore,
      pluginStore: PluginStore(
        baseDirectoryLoader: () async {
          final dir = Directory(p.join(tempDir.path, 'plugins'));
          await dir.create(recursive: true);
          return dir;
        },
      ),
      outputService: _FakeOutputService(<FileOutputItem>[
        FileOutputItem(
          id: 'out',
          path: largeOutput.path,
          name: 'export.pdf',
          scope: null,
          sourceLabel: 'PDF 工具输出',
          toolName: 'PDF',
          timestamp: DateTime(2026, 6, 8),
          exists: true,
          isDirectory: false,
          sizeBytes: 60 * 1024 * 1024,
          status: FileOutputStatus.scanOnly,
          inMaterialLibrary: false,
        ),
      ]),
      todoLoader: () async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'todo-1',
          'title': '提交实验作业',
          'deadline': DateTime(2026, 6, 8, 18).toIso8601String(),
        },
      ],
      clock: () => DateTime(2026, 6, 8, 10),
    );

    final insights = await service.generateInsights();
    final titles = insights.map((item) => item.title).join('\n');

    expect(titles, contains('待办即将截止'));
    expect(titles, contains('资料尚未进入搜索索引'));
    expect(titles, contains('今日有 1 张复习卡到期'));
    expect(titles, contains('输出文件未入资料库'));
    expect(titles, contains('复习卡来源缺失'));
  });

  test('ignored insights do not repeat in active list', () async {
    final service = SmartOrganizerService(
      todoLoader: () async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'todo-ignore',
          'title': '提交作业',
          'deadline': DateTime(2026, 6, 8, 18).toIso8601String(),
        },
      ],
      outputService: _FakeOutputService(const <FileOutputItem>[]),
      materialIndexService: _FakeMaterialIndexService(),
      pluginStore: PluginStore(
        baseDirectoryLoader: () async {
          final dir = Directory(p.join(tempDir.path, 'plugins'));
          await dir.create(recursive: true);
          return dir;
        },
      ),
      clock: () => DateTime(2026, 6, 8, 10),
    );

    final first = await service.generateInsights();
    await service.ignore(first.first.id);

    final second = await service.generateInsights();
    expect(second.where((item) => item.id == first.first.id), isEmpty);
  });
}

class _FakeOutputService extends FileOutputManagerService {
  _FakeOutputService(this.items);

  final List<FileOutputItem> items;

  @override
  Future<List<FileOutputItem>> loadOutputs({
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    return items;
  }
}

class _FakeMaterialIndexService extends MaterialIndexService {
  @override
  Future<List<MaterialIndexEntry>> loadIndex() async {
    return const <MaterialIndexEntry>[];
  }
}
