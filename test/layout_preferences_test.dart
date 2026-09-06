import 'dart:convert';

import 'package:course_helper/layout/layout_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layout preferences', () {
    test(
      'default upgrade keeps four visible tabs and allows restoring accounts',
      () {
        const ids = LayoutPreferences.defaultNavOrder;
        const defaults = LayoutPreferences();
        expect(defaults.visibleNavOrder(ids), [
          'courses',
          'todos',
          'tools',
          'settings',
        ]);
        final migrated = LayoutPreferences.fromJson({
          'navOrder': ids,
          'hiddenNavIds': <String>[],
        });
        expect(migrated.visibleNavOrder(ids), defaults.visibleNavOrder(ids));
        final restored = migrated.copyWith(hiddenNavIds: []);
        expect(
          LayoutPreferences.fromJson(restored.toJson()).visibleNavOrder(ids),
          ids,
        );
      },
    );
    test('custom navigation survives migration unchanged', () {
      final value = LayoutPreferences.fromJson({
        'navOrder': ['accounts', 'tools', 'courses', 'settings', 'todos'],
        'hiddenNavIds': ['todos'],
      });
      expect(value.visibleNavOrder(LayoutPreferences.defaultNavOrder), [
        'accounts',
        'tools',
        'courses',
        'settings',
      ]);
    });

    test('empty or corrupt JSON falls back to the five-entry default', () {
      expect(
        LayoutPreferencesStore.parse(null).navOrder,
        LayoutPreferences.defaultNavOrder,
      );
      expect(
        LayoutPreferencesStore.parse('{bad json').navOrder,
        LayoutPreferences.defaultNavOrder,
      );
    });

    test('normalization filters removed main navigation entries', () {
      final preferences = LayoutPreferences.fromJson(<String, dynamic>{
        'navOrder': <String>[
          'tools',
          'smart-organizer',
          'manual',
          'missing',
          'courses',
          'material-search',
        ],
        'hiddenNavIds': <String>['missing', 'accounts', 'manual'],
      });

      final normalized = preferences.normalized(
        navIds: LayoutPreferences.defaultNavOrder,
      );

      expect(normalized.navOrder, <String>[
        'tools',
        'courses',
        'accounts',
        'todos',
        'settings',
      ]);
      expect(normalized.hiddenNavIds, <String>['accounts']);
    });

    test('default navigation is strictly the requested five entries', () {
      expect(LayoutPreferences.defaultNavOrder, <String>[
        'courses',
        'accounts',
        'todos',
        'tools',
        'settings',
      ]);
      expect(LayoutPreferences.defaultNavOrder, isNot(contains('manual')));
      expect(
        LayoutPreferences.defaultNavOrder,
        isNot(contains('material-search')),
      );
      expect(
        LayoutPreferences.defaultNavOrder,
        isNot(contains('smart-organizer')),
      );
    });

    test('serializes hidden tool actions', () {
      const preferences = LayoutPreferences(
        toolActionOrder: <String>['a', 'b', 'c'],
        hiddenToolActionIds: <String>['b'],
      );

      final parsed = LayoutPreferences.fromJson(
        jsonDecode(jsonEncode(preferences.toJson())) as Map<String, dynamic>,
      );

      expect(parsed.visibleToolActionOrder(<String>['a', 'b', 'c']), [
        'a',
        'c',
      ]);
    });
  });
}
