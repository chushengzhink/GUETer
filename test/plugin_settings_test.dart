import 'dart:io';

import 'package:course_helper/plugins/plugin_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'plugin_store_test.dart' as store_test;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('插件设置', () {
    late Directory tempDir;
    late PluginStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp(
        'gueter_plugin_settings_',
      );
      store = PluginStore(baseDirectoryLoader: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('设置默认值和已保存值合并到插件私有命名空间', () async {
      await store_test.writePluginForTests(tempDir, 'settings.mod', '''
{
  "manifestVersion": 2,
  "id": "settings.mod",
  "name": {"zh": "设置", "en": "Settings"},
  "version": "1.0.0",
  "author": "Tester",
  "description": {"zh": "说明", "en": "Description"},
  "settingsSchema": [
    {"id": "prefix", "type": "text", "label": {"zh": "前缀", "en": "Prefix"}, "defaultValue": "A"},
    {"id": "enabled", "type": "toggle", "label": {"zh": "启用", "en": "Enabled"}, "defaultValue": true}
  ],
  "permissions": ["clipboard"],
  "entries": [
    {
      "id": "copy",
      "name": {"zh": "复制", "en": "Copy"},
      "description": {"zh": "复制", "en": "Copy"},
      "action": {"type": "copyText", "text": "{setting.prefix}"}
    }
  ]
}
''');

      final manifest = (await store.scan()).single;

      expect(await store.effectivePluginSettings(manifest), {
        'prefix': 'A',
        'enabled': true,
      });

      await store.setPluginSettings('settings.mod', {'prefix': 'B'});

      expect(await store.effectivePluginSettings(manifest), {
        'prefix': 'B',
        'enabled': true,
      });
    });

    test('插件私有目录位于插件目录下', () async {
      final dir = await store.pluginPrivateDirectory('demo.mod');

      expect(dir.path, p.join(tempDir.path, 'demo.mod', 'data'));
      expect(await dir.exists(), isTrue);
    });
  });
}
