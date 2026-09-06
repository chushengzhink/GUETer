import 'package:course_helper/widgets/unsaved_changes_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'failed save on back retains input and repeated back opens one dialog',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => UnsavedChangesGuard(
                      hasChanges: true,
                      onSave: () async => false,
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Editor')),
                        body: const Text('draft stays here'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Save and leave'));
      await tester.pumpAndSettle();
      expect(find.text('draft stays here'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard and leave'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    },
  );
}
