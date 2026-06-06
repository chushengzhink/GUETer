import 'dart:io';

import 'package:course_helper/plugins/plugin_action_menu.dart';
import 'package:course_helper/plugins/plugin_context.dart';
import 'package:course_helper/plugins/plugin_manifest.dart';
import 'package:course_helper/session/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('插件上下文动作', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      AppSettings.pluginStore.enabledPluginsNotifier.value = <PluginManifest>[];
    });

    test('按上下文、平台和扩展名过滤动作', () {
      final platform = Platform.operatingSystem;
      final manifest = PluginManifest.parse('''
{
  "manifestVersion": 2,
  "id": "context.mod",
  "name": {"zh": "上下文", "en": "Context"},
  "version": "1.0.0",
  "author": "Tester",
  "description": {"zh": "说明", "en": "Description"},
  "permissions": ["clipboard"],
  "entries": [
    {
      "id": "cloud-pdf",
      "name": {"zh": "云 PDF", "en": "Cloud PDF"},
      "description": {"zh": "复制", "en": "Copy"},
      "slots": ["filePreview"],
      "contexts": ["cloudFile"],
      "fileExtensions": ["pdf"],
      "platforms": ["$platform"],
      "action": {"type": "copyText", "text": "{fileName}"}
    },
    {
      "id": "local-txt",
      "name": {"zh": "本地 TXT", "en": "Local TXT"},
      "description": {"zh": "复制", "en": "Copy"},
      "contexts": ["file"],
      "fileExtensions": ["txt"],
      "action": {"type": "copyText", "text": "{fileName}"}
    }
  ]
}
''');
      AppSettings.pluginStore.enabledPluginsNotifier.value = [manifest];

      final actions = PluginActionMenu.actionsFor(
        const PluginActionContext(
          type: PluginContextType.cloudFile,
          fileName: 'paper.pdf',
        ),
      );

      expect(actions.map((item) => item.entry.id), <String>['cloud-pdf']);
    });
  });
}
