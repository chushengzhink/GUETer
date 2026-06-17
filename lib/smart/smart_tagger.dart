import 'package:path/path.dart' as p;

class SmartTagger {
  const SmartTagger();

  List<String> suggestTags({
    String title = '',
    String text = '',
    String path = '',
    String sourceLabel = '',
    bool isWebArchive = false,
    bool isOcr = false,
    bool isOutput = false,
  }) {
    final tags = <String>{};
    final haystack = [
      title,
      text,
      path,
      sourceLabel,
      p.basename(path),
    ].join(' ').toLowerCase();
    final original = [title, text, path, sourceLabel].join(' ');

    if (_containsAny(original, const ['考试', '测验', '测试', '期末', '期中']) ||
        _containsAny(haystack, const ['exam', 'quiz', 'test'])) {
      tags.add('考试');
    }
    if (_containsAny(original, const ['作业', '提交', '实验报告', '课程设计']) ||
        _containsAny(haystack, const ['homework', 'assignment'])) {
      tags.add('作业');
    }
    if (_containsAny(original, const ['通知', '公告']) ||
        _containsAny(haystack, const ['notice', 'announcement'])) {
      tags.add('通知');
    }
    if (_containsAny(original, const ['论文', '文献', '期刊', '摘要']) ||
        _containsAny(haystack, const ['paper', 'arxiv', 'doi', 'journal'])) {
      tags.add('论文');
    }
    if (_containsAny(original, const ['代码', '程序', '算法']) ||
        _containsAny(haystack, const [
          'github',
          'code',
          '.dart',
          '.py',
          '.java',
          '.cpp',
          '.js',
          '.ts',
        ])) {
      tags.add('代码');
    }
    if (_containsAny(original, const ['公式', '定理', '证明', '方程', '积分', '微分'])) {
      tags.add('公式');
    }
    if (_containsAny(original, const ['重点', '必考', '考点', '复习', '总结'])) {
      tags.add('重点');
    }
    if (_containsAny(original, const ['课件', '教材', '讲义', '课程资料'])) {
      tags.add('课程资料');
    }
    if (isWebArchive || _containsAny(haystack, const ['http://', 'https://'])) {
      tags.add('网页资料');
    }
    if (isOcr || _containsAny(haystack, const ['ocr', '扫描'])) {
      tags.add('OCR');
    }
    if (p.extension(path).toLowerCase() == '.pdf' ||
        _containsAny(haystack, const ['.pdf', ' pdf '])) {
      tags.add('PDF');
    }
    if (isOutput || _containsAny(original, const ['输出', '导出'])) {
      tags.add('输出');
    }

    return tags.toList()..sort();
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
