import 'package:course_helper/plugins/plugin_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validManifest = '''
{
  "id": "sample.links",
  "name": {"zh": "示例", "en": "示例"},
  "version": "1.0.0",
  "author": "Tester",
  "description": {"zh": "说明", "en": "说明"},
  "permissions": ["openExternalUrl", "localFileRead"],
  "entries": [
    {
      "id": "home",
      "name": {"zh": "官网", "en": "官网"},
      "description": {"zh": "打开", "en": "打开"},
      "action": {"type": "openUrl", "url": "https://example.com"}
    }
  ]
}
''';

  group('插件清单', () {
    test('可解析有效清单', () {
      final manifest = PluginManifest.parse(validManifest);

      expect(manifest.id, 'sample.links');
      expect(manifest.permissions, contains(PluginPermission.openExternalUrl));
      expect(manifest.entries.single.type, PluginActionType.openUrl);
      expect(manifest.entries.single.tags, isEmpty);
      expect(manifest.entries.single.priority, 0);
    });

    test('可解析入口 tags 和 priority', () {
      final raw = validManifest.replaceFirst(
        '"action": {"type": "openUrl", "url": "https://example.com"}',
        '"tags": ["link", " course "], '
            '"priority": 20, '
            '"action": {"type": "openUrl", "url": "https://example.com"}',
      );

      final entry = PluginManifest.parse(raw).entries.single;

      expect(entry.tags, <String>['link', 'course']);
      expect(entry.priority, 20);
    });

    test('可解析 Mod capabilities', () {
      final raw = validManifest.replaceFirst(
        '"permissions": ["openExternalUrl", "localFileRead"],',
        '"capabilities": ["quickCommand", "filePreviewAction"],\n'
            '"permissions": ["openExternalUrl", "localFileRead"],',
      );

      final manifest = PluginManifest.parse(raw);

      expect(manifest.capabilities, contains(PluginCapability.quickCommand));
      expect(
        manifest.capabilities,
        contains(PluginCapability.filePreviewAction),
      );
    });

    test('可解析入口级 slots、文件类型、平台和入口权限', () {
      final raw = validManifest.replaceFirst(
        '"action": {"type": "openUrl", "url": "https://example.com"}',
        '"slots": ["filePreview", "command"], '
            '"fileExtensions": ["pdf", ".TXT"], '
            '"platforms": ["Android", "windows"], '
            '"requiresPermissions": ["localFileRead"], '
            '"action": {"type": "previewFile"}',
      );

      final entry = PluginManifest.parse(raw).entries.single;

      expect(entry.type, PluginActionType.previewFile);
      expect(entry.slots, <PluginSlot>[
        PluginSlot.filePreview,
        PluginSlot.command,
      ]);
      expect(entry.fileExtensions, <String>['.pdf', '.txt']);
      expect(entry.platforms, <String>['android', 'windows']);
      expect(entry.requiresPermissions, <PluginPermission>[
        PluginPermission.localFileRead,
      ]);
    });

    test('入口级 slots 覆盖插件级 capabilities', () {
      final raw = validManifest
          .replaceFirst(
            '"permissions": ["openExternalUrl", "localFileRead"],',
            '"capabilities": ["toolEntry"],\n'
                '"permissions": ["openExternalUrl", "localFileRead"],',
          )
          .replaceFirst(
            '"action": {"type": "openUrl", "url": "https://example.com"}',
            '"slots": ["health"], '
                '"action": {"type": "openHealthCenter"}',
          );

      final manifest = PluginManifest.parse(raw);

      expect(manifest.entries.single.effectiveSlots(manifest.capabilities), [
        PluginSlot.health,
      ]);
    });

    test('默认 capabilities 为工具入口', () {
      final manifest = PluginManifest.parse(validManifest);

      expect(manifest.capabilities, <PluginCapability>[
        PluginCapability.toolEntry,
      ]);
    });

    test('拒绝非法 tags 类型', () {
      final raw = validManifest.replaceFirst(
        '"action": {"type": "openUrl", "url": "https://example.com"}',
        '"tags": "link", '
            '"action": {"type": "openUrl", "url": "https://example.com"}',
      );

      expect(
        () => PluginManifest.parse(raw),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('拒绝未知权限', () {
      final raw = validManifest.replaceFirst(
        '"openExternalUrl"',
        '"accountAccess"',
      );

      expect(
        () => PluginManifest.parse(raw),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('拒绝未知动作', () {
      final raw = validManifest.replaceFirst('"openUrl"', '"runDart"');

      expect(
        () => PluginManifest.parse(raw),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('拒绝未知 Mod capability', () {
      final raw = validManifest.replaceFirst(
        '"permissions": ["openExternalUrl", "localFileRead"],',
        '"capabilities": ["runNativeCode"],\n'
            '"permissions": ["openExternalUrl", "localFileRead"],',
      );

      expect(
        () => PluginManifest.parse(raw),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('拒绝未知入口位置', () {
      final raw = validManifest.replaceFirst(
        '"action": {"type": "openUrl", "url": "https://example.com"}',
        '"slots": ["shell"], '
            '"action": {"type": "openUrl", "url": "https://example.com"}',
      );

      expect(
        () => PluginManifest.parse(raw),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('可解析新增受控动作', () {
      for (final action in <String>[
        'previewFile',
        'shareText',
        'shareFile',
        'openFolder',
        'openHealthCenter',
        'openDuplicateCleanup',
        'sequence',
        'showMessage',
        'pickFile',
        'saveTextFile',
        'openBuiltinTool',
        'sendToLocalTransfer',
        'openWithFileTool',
        'copyJsonField',
      ]) {
        final raw = validManifest.replaceFirst('"openUrl"', '"$action"');
        expect(PluginManifest.parse(raw).entries.single.type.id, action);
      }
    });

    test('可解析 v2 contexts、settingsSchema 和 allowedHosts', () {
      final raw = validManifest
          .replaceFirst(
            '"id": "sample.links",',
            '"manifestVersion": 2,\n  "id": "sample.links",',
          )
          .replaceFirst(
            '"permissions": ["openExternalUrl", "localFileRead"],',
            '"allowedHosts": ["example.com"],\n'
                '"settingsSchema": [{"id": "prefix", "type": "text", "label": {"zh": "前缀", "en": "Prefix"}, "defaultValue": "GUETer"}],\n'
                '"permissions": ["openExternalUrl", "localFileRead", "localFileWrite"],',
          )
          .replaceFirst(
            '"action": {"type": "openUrl", "url": "https://example.com"}',
            '"contexts": ["file", "cloudFile"], '
                '"action": {"type": "saveTextFile", "text": "{fileName}"}',
          );

      final manifest = PluginManifest.parse(raw);

      expect(manifest.manifestVersion, 2);
      expect(manifest.allowedHosts, <String>['example.com']);
      expect(manifest.settingsSchema.single.id, 'prefix');
      expect(manifest.settingsSchema.single.type, PluginSettingType.text);
      expect(manifest.entries.single.contexts, <PluginContextType>[
        PluginContextType.file,
        PluginContextType.cloudFile,
      ]);
      expect(manifest.permissions, contains(PluginPermission.localFileWrite));
    });

    test('拒绝非法 v2 host', () {
      final raw = validManifest.replaceFirst(
        '"permissions": ["openExternalUrl", "localFileRead"],',
        '"allowedHosts": ["https://example.com/path"],\n'
            '"permissions": ["openExternalUrl", "localFileRead"],',
      );

      expect(
        () => PluginManifest.parse(raw),
        throwsA(isA<PluginManifestException>()),
      );
    });

    test('要求填写本地化名称', () {
      final raw = validManifest.replaceFirst(
        '"name": {"zh": "示例", "en": "示例"},',
        '"name": {},',
      );

      expect(
        () => PluginManifest.parse(raw),
        throwsA(isA<PluginManifestException>()),
      );
    });
  });
}
