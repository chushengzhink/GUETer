import 'package:flutter_test/flutter_test.dart';

import 'package:course_helper/plugins/plugin_manifest.dart';
import 'package:course_helper/plugins/plugin_template.dart';

void main() {
  test('built-in plugin templates generate valid manifests', () {
    const library = PluginTemplateLibrary();
    final templates = library.all();

    expect(templates.length, greaterThanOrEqualTo(6));
    for (final template in templates) {
      final manifest = PluginManifest.parse(template.manifestJson());
      expect(manifest.id, template.id);
      expect(manifest.entries, isNotEmpty);
    }
  });
}
