import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:course_helper/features/unipus/unipus_models.dart';
import 'package:course_helper/features/unipus/unipus_service.dart';

void main() {
  test('UnipusAssistConfig round trips without unsaved password', () {
    const config = UnipusAssistConfig(
      username: 'student',
      password: 'secret',
      rememberPassword: false,
      tutorialId: 'course-v1:demo',
      reviewMode: true,
      openAiBaseUrl: 'https://api.deepseek.com',
      openAiModel: 'deepseek-chat',
    );

    final json = config.toJson();
    expect(json['password'], isEmpty);

    final restored = UnipusAssistConfig.fromJson(json);
    expect(restored.username, 'student');
    expect(restored.password, isEmpty);
    expect(restored.reviewMode, isTrue);
    expect(restored.openAiBaseUrl, 'https://api.deepseek.com');
    expect(restored.openAiModel, 'deepseek-chat');
  });

  test('captcha challenge decodes plain base64 and data uri', () {
    final raw = base64Encode(<int>[1, 2, 3, 4]);

    expect(
      const UnipusCaptchaChallenge(
        imageBase64: 'AQIDBA==',
        encodedCaptcha: 'encoded',
      ).imageBytes(),
      <int>[1, 2, 3, 4],
    );
    expect(
      UnipusCaptchaChallenge(
        imageBase64: 'data:image/png;base64,$raw',
        encodedCaptcha: 'encoded',
      ).imageBytes(),
      <int>[1, 2, 3, 4],
    );
  });

  test('parseCourseBlocks reads Unipus course cards', () {
    final blocks = UnipusService().parseCourseBlocks('''
      <div class="class-content">
        <div class="class-name">英语班课</div>
        <div class="class-date">2026.1.1 至 2026.6.30</div>
        <div class="my_course_item" tutorialid="course-v1:Unipus+demo+2026">
          <span class="my_course_name" title="综合英语"></span>
          <span class="my_course_status">进行中</span>
          <img class="my_course_cover" src="//cdn.example.com/a.png" />
          <span class="hideurl">://ucontent.unipus.cn/path?courseId=1&amp;school_id=2&amp;eccId=3&amp;classId=4&amp;coursetype=5</span>
        </div>
      </div>
    ''');

    expect(blocks, hasLength(1));
    expect(blocks.single.className, '英语班课');
    expect(blocks.single.startDate, '2026-1-1');
    expect(blocks.single.endDate, '2026-6-30');
    expect(blocks.single.courses, hasLength(1));
    final course = blocks.single.courses.single;
    expect(course.courseName, '综合英语');
    expect(course.status, '进行中');
    expect(course.image, 'https://cdn.example.com/a.png');
    expect(course.courseUrl.startsWith('https://'), isTrue);
    expect(course.tutorialId, 'course-v1:Unipus+demo+2026');
    expect(course.courseId, '1');
  });

  test('exportQueueMarkdown includes confirmation state and task url', () {
    const node = UnipusTaskNode(
      tutorialId: 'course-v1:demo',
      title: 'Unit 1',
      path: <int>[1],
      leaf: '/u1/u1g1',
      url: 'https://ucontent.unipus.cn/unit',
      required: true,
      passed: false,
      children: <UnipusTaskNode>[],
    );
    const queue = <UnipusQueueItem>[
      UnipusQueueItem(id: '1', courseName: '综合英语', node: node),
    ];

    final markdown = UnipusService().exportQueueMarkdown(queue);

    expect(markdown, contains('U 校园辅助任务清单'));
    expect(markdown, contains('[待确认] 综合英语 / 1 Unit 1'));
    expect(markdown, contains('https://ucontent.unipus.cn/unit'));
  });
}
