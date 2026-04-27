import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

class ChaoxingHtmlParser {
  Map<String, dynamic> parseCoursePoint(String htmlText) {
    try {
      final document = html_parser.parse(htmlText);
      final coursePoint = {
        'hasLocked': false,
        'points': <Map<String, dynamic>>[],
      };

      final chapterUnits = <dynamic>[];
      chapterUnits.addAll(document.querySelectorAll('div.chapter_unit'));
      chapterUnits.addAll(document.querySelectorAll('div.chapter'));
      chapterUnits.addAll(document.querySelectorAll('ul.chapter-list'));

      for (final chapterUnit in chapterUnits) {
        final points = _extractPointsFromChapter(chapterUnit);

        for (final point in points) {
          if (point['need_unlock'] == true) {
            coursePoint['hasLocked'] = true;
          }
        }

        (coursePoint['points'] as List<Map<String, dynamic>>).addAll(points);
      }

      return coursePoint;
    } catch (e) {
      return {
        'hasLocked': false,
        'points': <Map<String, dynamic>>[],
      };
    }
  }

  List<Map<String, dynamic>> _extractPointsFromChapter(dynamic chapterUnit) {
    final pointList = <Map<String, dynamic>>[];

    try {
      final pointElements = [
        ...chapterUnit.querySelectorAll('div.chapter_item'),
        ...chapterUnit.querySelectorAll('li'),
        ...chapterUnit.querySelectorAll('div.knowledge'),
      ];

      for (final pointElement in pointElements) {
        try {
          String rawId = pointElement.attributes['id'] ?? '';
          String knowledgeId = '';
          if (rawId.isNotEmpty) {
            final m = RegExp(r'(\d{3,})').firstMatch(rawId);
            if (m != null) knowledgeId = m.group(1) ?? '';
          }

          if (knowledgeId.isEmpty) {
            final href = pointElement.querySelector('a')?.attributes['href'] ?? '';
            final m = RegExp(r'knowledgeid=(\d{3,})').firstMatch(href);
            if (m != null) knowledgeId = m.group(1) ?? '';
          }

          String title =
              pointElement.querySelector('h3')?.text.trim() ??
              pointElement.querySelector('span.chapter_item_title')?.text.trim() ??
              pointElement.querySelector('span.chapter-title')?.text.trim() ??
              pointElement.querySelector('a')?.text.trim() ??
              '';

          if (knowledgeId.isNotEmpty && title.isNotEmpty) {
            final needUnlock = pointElement.classes.contains('lock') ||
                pointElement.querySelector('.lock') != null;

            pointList.add({
              'id': knowledgeId,
              'title': title,
              'need_unlock': needUnlock,
            });
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      // ignore
    }

    return pointList;
  }

  Map<String, dynamic> parseJobList(String htmlText) {
    try {
      if (htmlText.contains('章节未开放')) {
        return {
          'jobList': <Map<String, dynamic>>[],
          'jobInfo': {'notOpen': true},
        };
      }

      final cleanedHtml = htmlText.replaceAll(' ', '');
      final mArgMatches = RegExp(r'mArg=\{(.*?)\};').allMatches(cleanedHtml);

      if (mArgMatches.isEmpty) {
        return {
          'jobList': <Map<String, dynamic>>[],
          'jobInfo': <String, dynamic>{},
        };
      }

      final mArgContent = mArgMatches.first.group(1)!;
      final cardsData = jsonDecode('{$mArgContent}') as Map<String, dynamic>;

      if (cardsData.isEmpty) {
        return {
          'jobList': <Map<String, dynamic>>[],
          'jobInfo': <String, dynamic>{},
        };
      }

      final jobInfo = _extractJobInfo(cardsData);
      final cards = cardsData['attachments'] as List<dynamic>? ?? [];
      final jobList = _processAttachmentCards(cards.cast<Map<String, dynamic>>());

      return {
        'jobList': jobList,
        'jobInfo': jobInfo,
      };
    } catch (e) {
      return {
        'jobList': <Map<String, dynamic>>[],
        'jobInfo': <String, dynamic>{},
      };
    }
  }

  Map<String, dynamic> _extractJobInfo(Map<String, dynamic> cardsData) {
    final defaults = cardsData['defaults'] as Map<String, dynamic>? ?? {};
    if (defaults.isEmpty) {
      return {};
    }

    return {
      'ktoken': defaults['ktoken'] ?? '',
      'mtEnc': defaults['mtEnc'] ?? '',
      'reportTimeInterval': defaults['reportTimeInterval'] ?? 60,
      'defenc': defaults['defenc'] ?? '',
      'cardid': defaults['cardid'] ?? '',
      'cpi': defaults['cpi'] ?? '',
      'qnenc': defaults['qnenc'] ?? '',
      'knowledgeid': defaults['knowledgeid'] ?? '',
    };
  }

  List<Map<String, dynamic>> _processAttachmentCards(List<Map<String, dynamic>> cards) {
    final jobList = <Map<String, dynamic>>[];

    for (final card in cards) {
      if (card['isPassed'] == true) {
        continue;
      }

      if (card['job'] == null) {
        final readJob = _processReadTask(card);
        if (readJob != null) {
          jobList.add(readJob);
        }
        continue;
      }

      if (card.containsKey('otherInfo')) {
        card['otherInfo'] = (card['otherInfo'] as String).split('&')[0];
      }

      final cardType = card['type']?.toString() ?? '';
      if (cardType == 'video') {
        final videoJob = _processVideoTask(card);
        if (videoJob != null) {
          jobList.add(videoJob);
        }
      } else if (cardType == 'document') {
        final docJob = _processDocumentTask(card);
        if (docJob != null) {
          jobList.add(docJob);
        }
      } else if (cardType == 'workid') {
        final workJob = _processWorkTask(card);
        if (workJob != null) {
          jobList.add(workJob);
        }
      }
    }

    return jobList;
  }

  Map<String, dynamic>? _processReadTask(Map<String, dynamic> card) {
    return {
      'type': 'read',
      'title': card['property']?['name'] ?? '阅读任务',
      'objectId': card['objectId'] ?? '',
      'isPassed': false,
    };
  }

  Map<String, dynamic>? _processVideoTask(Map<String, dynamic> card) {
    final property = card['property'] as Map<String, dynamic>? ?? {};
    return {
      'type': 'video',
      'title': property['name'] ?? '视频任务',
      'objectId': card['objectId'] ?? '',
      'jobId': card['jobid'] ?? '',
      'duration': property['duration'] ?? 0,
      'isPassed': false,
    };
  }

  Map<String, dynamic>? _processDocumentTask(Map<String, dynamic> card) {
    final property = card['property'] as Map<String, dynamic>? ?? {};
    return {
      'type': 'document',
      'title': property['name'] ?? '文档任务',
      'objectId': card['objectId'] ?? '',
      'jobId': card['jobid'] ?? '',
      'isPassed': false,
    };
  }

  Map<String, dynamic>? _processWorkTask(Map<String, dynamic> card) {
    return {
      'type': 'work',
      'title': card['property']?['title'] ?? '作业任务',
      'workId': card['workid'] ?? '',
      'isPassed': false,
    };
  }
}
