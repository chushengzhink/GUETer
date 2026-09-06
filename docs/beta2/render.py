"""Render real page builds with fixture data; never contacts a real platform.

The baseline is commit 4277305. Only initState is replaced in copied course,
account and todo pages to seed data and disable external services. Production
build methods are left intact. Temporary source copies are removed in finally.
"""
from pathlib import Path
import subprocess
import shutil
import sys

root = Path(__file__).resolve().parents[2]
created = []

def write(relative, text):
    target = root / relative
    if target.exists():
        raise RuntimeError(f'Refusing to replace temporary file: {target}')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')
    created.append(target)

def baseline(relative):
    return subprocess.check_output(['git', 'show', f'4277305:{relative}'], cwd=root).decode('utf-8')

def fixture_init(source, state, body):
    start = source.index('  void initState() {', source.index(state))
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[:opening + 1] + '\n    super.initState();\n' + body + '\n  }' + source[end:]

courses = """
    _courses = [
      Course(courseId: '1', classId: 'a', image: '', name: '计算机网络', teacher: '张老师 · 周一 3–4 节', state: true),
      Course(courseId: '2', classId: 'a', image: '', name: '操作系统', teacher: '李老师 · 周二 1–2 节', state: true),
      Course(courseId: '3', classId: 'a', image: '', name: '数据库原理', teacher: '王老师 · 周三 5–6 节', state: true),
    ];
    _isLoading = false;
"""

try:
    before = fixture_init(baseline('lib/pages/courses.dart'), 'class CoursesPageState', courses)
    before = before.replace("'../features/courses/course_load_controller.dart'", "'beta2_fixture_course_controller.dart'")
    write('lib/pages/beta2_fixture_before_courses.dart', before)
    write('lib/pages/beta2_fixture_course_controller.dart', baseline('lib/features/courses/course_load_controller.dart').replace("'../../models/course.dart'", "'../models/course.dart'").replace("'../../platform.dart'", "'../platform.dart'"))
    write('lib/pages/beta2_fixture_after_courses.dart', fixture_init((root/'lib/pages/courses.dart').read_text(encoding='utf-8'), 'class CoursesPageState', courses))
    write('lib/pages/beta2_fixture_before_accounts.dart', fixture_init(baseline('lib/pages/accounts.dart'), 'class _AccountsPageState', "    _accounts = AccountManager.getAccountsForPlatform(PlatformManager().currentPlatform);\n    _currentAccountId = AccountManager.currentSessionId;"))
    write('lib/pages/beta2_fixture_before_number.dart', baseline('lib/pages/tronclass_number_sign_page.dart'))
    for old in [True, False]:
        source = baseline('lib/pages/todos_page.dart') if old else (root/'lib/pages/todos_page.dart').read_text(encoding='utf-8')
        source = fixture_init(source, 'class _TodosPageState', """
    _isInitializing = false;
    _platformData[PlatformType.tronclass] = TodoPlatformData(ownerUserId: 'T', pendingTodos: [
      {'id': 1, 'type': 'homework', 'title': '第三章：网络协议分析', 'course_name': '计算机网络', 'end_time': '2026-09-09T18:00:00'},
      {'id': 2, 'type': 'homework', 'title': '实验二：进程调度', 'course_name': '操作系统', 'end_time': '2026-09-10T18:00:00'},
    ]);
""")
        write(f'lib/pages/beta2_fixture_{"before" if old else "after"}_todos.dart', source)
    write('lib/theme/beta2_fixture_before_theme.dart', baseline('lib/theme/app_theme.dart'))
    write('_tmp/beta2_render_test.dart', (root/'docs/beta2/render_test.dart.txt').read_text(encoding='utf-8'))
    (root/'docs/beta2/screenshots').mkdir(parents=True, exist_ok=True)
    for mode in ['light', 'dark']:
        shutil.copyfile(root/f'docs/beta/tools-after-{mode}.png', root/f'docs/beta2/screenshots/tools-before-{mode}.png')
    flutter = sys.argv[1] if len(sys.argv) > 1 else 'E:/Flutter/bin/flutter.bat'
    result = subprocess.run([flutter, 'test', '--no-pub', '_tmp/beta2_render_test.dart', '--reporter', 'expanded'], cwd=root)
    exit_code = result.returncode
finally:
    for target in reversed(created):
        if target.resolve().is_relative_to(root) and 'beta2_' in target.name:
            target.unlink(missing_ok=True)
sys.exit(exit_code)
