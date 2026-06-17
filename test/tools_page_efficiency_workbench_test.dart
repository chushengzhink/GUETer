import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/pages/tools_page.dart').readAsStringSync();
  });

  test('tools page includes efficiency workbench and output inbox', () {
    expect(source, contains('class _ToolEfficiencyOverview'));
    expect(source, contains('FileOutputManagerSummary? _outputSummary'));
    expect(source, contains('_outputManagerService.loadSummary'));
    expect(source, contains('onOpenOutputManager: _openOutputManager'));
  });

  test('tools page exposes recommended workflow recipes', () {
    expect(source, contains('class _RecommendedWorkflowPanel'));
    expect(source, contains('ToolWorkflowRecipe'));
    expect(source, contains("id: 'pdf-inbox'"));
    expect(source, contains("id: 'transfer-package'"));
    expect(source, contains("id: 'archive-search'"));
  });
}
