import 'package:course_helper/l10n/app_localizations.dart';
import 'package:course_helper/pages/apod_detail_page.dart';
import 'package:course_helper/services/nasa_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  group('ApodDetailPage', () {
    testWidgets('pushes full screen preview when image is tapped', (
      tester,
    ) async {
      const apod = NasaApodData(
        title: 'Pillars of Creation',
        url: 'https://example.com/apod.jpg',
        explanation: 'A nebula image.',
        date: '2026-05-20',
        mediaType: 'image',
      );

      await tester.pumpWidget(buildTestApp(const ApodDetailPage(apod: apod)));

      expect(find.byKey(const Key('apodDetailImageTapTarget')), findsOneWidget);
      expect(find.byKey(const Key('apodImagePreviewPage')), findsNothing);

      await tester.tap(find.byKey(const Key('apodDetailImageTapTarget')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(const Key('apodImagePreviewPage')), findsOneWidget);
      expect(
        find.byKey(const Key('apodImagePreviewInteractiveViewer')),
        findsOneWidget,
      );
    });

    testWidgets('shows non-image notice without zoom entry for non-image APOD', (
      tester,
    ) async {
      const apod = NasaApodData(
        title: 'APOD Video',
        url: 'https://example.com/apod-video',
        explanation: 'A video explanation.',
        date: '2026-05-20',
        mediaType: 'video',
      );

      await tester.pumpWidget(buildTestApp(const ApodDetailPage(apod: apod)));
      await tester.pump();

      expect(find.byKey(const Key('apodDetailImageTapTarget')), findsNothing);
      expect(find.byKey(const Key('apodImageZoomHint')), findsNothing);
      expect(find.text('NASA 今日 APOD 不是图片，原始内容可能是视频或其他媒体类型。'), findsOneWidget);
    });
  });
}
