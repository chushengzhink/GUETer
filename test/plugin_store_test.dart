import 'dart:io';

import 'package:course_helper/plugins/plugin_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('插件仓库', () {
    late Directory tempDir;
    late PluginStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('gueter_plugin_store_');
      store = PluginStore(baseDirectoryLoader: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('扫描有效插件并记录无效插件错误', () async {
      await writePluginForTests(tempDir, 'valid.mod', '''
{
  "id": "valid.mod",
  "name": {"zh": "有效", "en": "Valid"},
  "version": "1.0.0",
  "author": "Tester",
  "description": {"zh": "说明", "en": "Description"},
  "permissions": ["clipboard"],
  "entries": [
    {
      "id": "copy",
      "name": {"zh": "复制", "en": "Copy"},
      "description": {"zh": "复制", "en": "Copy"},
      "action": {"type": "copyText", "text": "hello"}
    }
  ]
}
''');
      await writePluginForTests(tempDir, 'invalid.mod', '{"id": "broken"}');

      final manifests = await store.scan();

      expect(manifests.single.id, 'valid.mod');
      expect(store.discoveredPluginsNotifier.value.single.id, 'valid.mod');
      expect(
        store.invalidPluginsNotifier.value.single.directoryName,
        'invalid.mod',
      );
      expect(store.invalidPluginsNotifier.value.single.error, isNotEmpty);
    });

    test('生成示例 Mod 后可被扫描和解析', () async {
      final manifest = await store.createExampleMod();

      expect(manifest.id, 'gueter.example.mod');
      expect(
        await File(
          p.join(tempDir.path, 'gueter.example.mod', 'plugin.json'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(tempDir.path, 'gueter.example.mod', 'README.md'),
        ).exists(),
        isTrue,
      );
      expect(
        store.discoveredPluginsNotifier.value.map((item) => item.id),
        contains('gueter.example.mod'),
      );
      expect(store.invalidPluginsNotifier.value, isEmpty);
    });
  });
}

Future<void> writePluginForTests(
  Directory base,
  String name,
  String manifest,
) async {
  final dir = Directory(p.join(base.path, name));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'plugin.json')).writeAsString(manifest);
}
