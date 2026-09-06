import 'package:course_helper/app_entries/app_entry.dart';
import 'package:course_helper/layout/lazy_destination_stack.dart';
import 'package:course_helper/widgets/floating_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigation responds before animation and handles rapid taps', (
    tester,
  ) async {
    final selections = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingNavBar(
            currentIndex: 0,
            onTap: selections.add,
            items: const [
              FloatingNavBarItem(icon: Icons.school, label: 'Courses'),
              FloatingNavBarItem(icon: Icons.build, label: 'Tools'),
              FloatingNavBarItem(icon: Icons.settings, label: 'Settings'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tools'));
    expect(selections, [1]);
    await tester.tap(find.text('Settings'));
    expect(selections, [1, 2]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lazy pages survive reorder and keep input while offstage', (
    tester,
  ) async {
    final initialized = <String>[];
    AppEntry entry(String id) => AppEntry(
      id: id,
      titleZh: id,
      titleEn: id,
      icon: Icons.school,
      builder: (_) => _Probe(id, initialized),
    );
    final entries = [entry('courses'), entry('tools'), entry('settings')];
    Future<void> show(String id, List<AppEntry> order) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LazyDestinationStack(entries: order, selectedId: id),
        ),
      ),
    );
    await show('courses', entries);
    expect(initialized, ['courses']);
    await tester.enterText(find.byType(TextField), 'preserved draft');
    await show('tools', entries);
    expect(initialized, ['courses', 'tools']);
    expect(find.text('preserved draft'), findsNothing);
    await show('courses', entries.reversed.toList());
    expect(find.text('preserved draft'), findsOneWidget);
    expect(initialized, ['courses', 'tools']);
  });

  testWidgets('one visible destination remains accessible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: FloatingNavBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              FloatingNavBarItem(icon: Icons.school, label: 'Courses'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Courses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Probe extends StatefulWidget {
  const _Probe(this.id, this.initialized);
  final String id;
  final List<String> initialized;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.initialized.add(widget.id);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: controller);
}
