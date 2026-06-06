import 'dart:io';

import 'package:course_helper/plugins/plugin_manifest.dart';
import 'package:course_helper/plugins/plugin_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

PluginManifest _manifest(
  String entries, {
  String capabilities = '"toolEntry"',
  String permissions =
      '"clipboard", "localFileRead", "network", "openExternalUrl", "localFileWrite"',
  String extra = '',
}) {
  return PluginManifest.parse('''
{
  "id": "runtime.mod",
  "name": {"zh": "运行时", "en": "Runtime"},
  "version": "1.0.0",
  "author": "Tester",
  "description": {"zh": "说明", "en": "Description"},
  $extra
  "capabilities": [$capabilities],
  "permissions": [$permissions],
  "entries": [$entries]
}
''');
}

String _entry({
  required String id,
  required String type,
  String? slots = '"tool"',
  String extra = '',
  String actionExtra = '',
}) {
  final slotsLine = slots == null ? '' : '"slots": [$slots],';
  return '''
{
  "id": "$id",
  "name": {"zh": "$id", "en": "$id"},
  "description": {"zh": "$id", "en": "$id"},
  $slotsLine
  $extra
  "action": {"type": "$type"$actionExtra}
}
''';
}

void main() {
  group('插件运行时', () {
    test('文件预览动作按 slot、平台和扩展名过滤', () {
      final platform = Platform.operatingSystem;
      final manifest = _manifest(
        [
          _entry(
            id: 'pdf',
            type: 'copyText',
            slots: '"filePreview"',
            extra: '"fileExtensions": ["pdf"], "platforms": ["$platform"],',
            actionExtra: ', "text": "{filePath}"',
          ),
          _entry(
            id: 'txt',
            type: 'copyText',
            slots: '"filePreview"',
            extra: '"fileExtensions": ["txt"],',
            actionExtra: ', "text": "{filePath}"',
          ),
          _entry(
            id: 'tool-only',
            type: 'copyText',
            slots: '"tool"',
            actionExtra: ', "text": "x"',
          ),
        ].join(','),
        capabilities: '"filePreviewAction", "toolEntry"',
      );

      final actions = PluginRuntime.filePreviewActions([
        manifest,
      ], p('paper.pdf'));

      expect(actions.map((item) => item.entry.id), <String>['pdf']);
    });

    test('占位符不会包含敏感会话字段', () async {
      final value = await PluginRuntime.applyPlaceholdersForTests(
        '{filePath}|{fileUri}|{fileName}|{fileExt}|{appVersion}|{platform}',
        filePath: p('docs', 'note.txt'),
      );

      expect(value, contains('note.txt'));
      expect(value, contains('.txt'));
      expect(value, isNot(contains('cookie')));
      expect(value, isNot(contains('token')));
      expect(value, isNot(contains('session')));
    });

    test('文件预览动作兼容旧插件级 capability', () {
      final manifest = _manifest(
        _entry(
          id: 'legacy',
          type: 'copyText',
          slots: null,
          actionExtra: ', "text": "{filePath}"',
        ),
        capabilities: '"filePreviewAction"',
      );

      final actions = PluginRuntime.filePreviewActions([
        manifest,
      ], p('note.txt'));

      expect(actions.single.entry.id, 'legacy');
    });

    test('入口级 filePreview slot 不依赖插件级 capability', () {
      final manifest = _manifest(
        _entry(
          id: 'entry-slot',
          type: 'copyText',
          slots: '"filePreview"',
          actionExtra: ', "text": "{filePath}"',
        ),
        capabilities: '"toolEntry"',
      );

      final actions = PluginRuntime.filePreviewActions([
        manifest,
      ], p('note.txt'));

      expect(actions.single.entry.id, 'entry-slot');
    });

    test('上下文占位符和文件大小可用且不泄露敏感字段', () async {
      final value = await PluginRuntime.applyPlaceholdersForTests(
        '{fileName}|{fileExt}|{fileSize}|{text}|{platform}',
        filePath: p('docs', 'note.txt'),
      );

      expect(value, contains('note.txt'));
      expect(value, contains('.txt'));
      expect(value, isNot(contains('password')));
      expect(value, isNot(contains('session')));
    });

    test('allowedHosts 阻止未声明 host', () {
      final manifest = _manifest(
        _entry(
          id: 'blocked',
          type: 'openUrl',
          actionExtra: ', "url": "https://blocked.example/path"',
        ),
        extra: '"allowedHosts": ["example.com"],',
      );

      expect(
        () => PluginRuntime.validateAllowedHostForTests(
          manifest,
          'https://blocked.example/path',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

String p(String part1, [String? part2]) {
  return part2 == null ? part1 : '$part1${Platform.pathSeparator}$part2';
}
