import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform.dart';
import '../api/course.dart';
import '../api/api_service.dart';
import '../api/kt_sign.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../models/course.dart';
import '../models/active.dart';
import '../utils/global_palette.dart';
import 'widget/scan.dart';
import 'widget/avatar.dart';
import 'actives/sign_in/sign_in.dart';
import 'actives/topic_discuss.dart';
import 'actives/quiz.dart';
import 'actives/evaluate.dart';
import 'actives/vote.dart';
import 'actives/questionnaire.dart';
import 'accounts.dart';
import 'presentation.dart';
import 'tronclass_sign_in.dart';
import 'tronclass_web_login.dart';
import 'ketangpai_course_struct.dart';


class CourseContentPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String classId;
  final String cpi;

  const CourseContentPage({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.classId,
    required this.cpi,
  });

  @override
  State<CourseContentPage> createState() => _CourseContentPageState();
}

class _CourseContentPageState extends State<CourseContentPage> {
  List<Active> _activeList = [];
  bool _isContentLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCourseContent();
  }

  Future<void> _loadCourseContent() async {
    setState(() {
      _isContentLoading = true;
    });

    try {
      final List<Active>? contentList = await CXCourseApi.getActiveList(
        widget.courseId,
        widget.classId,
        widget.cpi,
      );

      if (contentList != null) {
        setState(() {
          _activeList = contentList;
          _isContentLoading = false;
        });
      } else {
        setState(() {
          _activeList = [];
          _isContentLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取内容列表失败')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _activeList = [];
        _isContentLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取内容列表时发生错误：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isContentLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeList.isEmpty
          ? const Center(
        child: Text(
          '暂无内容',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadCourseContent,
        child: ListView.builder(
          itemCount: _activeList.length,
          itemBuilder: (context, index) {
            var active = _activeList[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active.getIcon(),
                    color: active.status
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    size: 35,
                  ),
                ),
                title: Text(
                  active.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  active.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (active.status) {
                    switch (active.activeType) {
                      case ActiveType.signIn:
                      case ActiveType.signOut:
                      case ActiveType.scheduledSignIn:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignInPage(
                              active: active,
                              courseId: widget.courseId,
                              classId: widget.classId,
                              cpi: widget.cpi
                            ),
                          ),
                        );
                        break;
                      
                      case ActiveType.topicDiscuss:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TopicDiscussPage(active: active),
                          ),
                        );
                        break;
                      
                      case ActiveType.quiz:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizPage(
                              active: active,
                              courseId: widget.courseId,
                              classId: widget.classId
                            ),
                          ),
                        );
                        break;
                      
                      case ActiveType.evaluation:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EvaluatePage(
                              active: active,
                              courseId: widget.courseId,
                              classId: widget.classId
                            ),
                          ),
                        );
                        break;
                      
                      case ActiveType.vote:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VotePage(
                              active: active,
                              courseId: widget.courseId,
                              classId: widget.classId
                            ),
                          ),
                        );
                        break;

                        case ActiveType.questionnaire:
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestionnairePage(
                              active: active,
                              courseId: widget.courseId,
                              classId: widget.classId
                            ),
                          ),
                        );
                        break;
                      
                      default:
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('该活动类型暂不支持'),
                          ),
                        );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('该活动已结束')),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

final GlobalKey coursesPageKey = GlobalKey();

class _CoursesPageState extends State<CoursesPage> with WidgetsBindingObserver {
  List<Course> _courses = [];
  bool _isLoading = true;
  StreamSubscription? _accountChangeSubscription;
  StreamSubscription? _platformChangeSubscription;
  Timer? _refreshTimer;
  Map<String, dynamic>? _lastOnLessonCourses;
  bool _isVisible = false;
  Color _globalPrimary = const Color(0xFF1F9EA8);
  Color _globalSecondary = const Color(0xFF157B88);
  Color _globalAccent = const Color(0xFF59BE30);

  void refreshCourses() {
    _loadCourses();
  }

  void onVisibilityChanged(bool visible) {
    _isVisible = visible;
    if (visible) {
      _checkAndStartRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  /// 使用在线课堂数据更新课程列表
  void updateWithOnLessonCourses(Map<String, dynamic> onLessonCourses) {
    _loadCourses(onLessonCourses);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.globalColorSchemeNotifier.addListener(_onGlobalSchemeChanged);
    _isVisible = true;
    _loadGlobalPalette();
    _loadCourses();

    // 监听账户变更事件
    _accountChangeSubscription =
        AccountChangeNotifier().accountChanges.listen((accountId) {
          if (mounted) {
            _loadCourses();
          }
        });

    // 监听平台变化
    _platformChangeSubscription = PlatformManager().platformChanges.listen((_) {
      if (mounted) {
        _lastOnLessonCourses = null;
        _loadCourses();
      }
      _checkAndStartRefresh();
    });

    _checkAndStartRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndStartRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  void _checkAndStartRefresh() {
    _refreshTimer?.cancel();
    if (_isVisible && PlatformManager().isRainClassroom) {
      _startPeriodicRefresh();
    }
  }

  void _loadGlobalPalette() {
    final scheme = AppSettings.globalColorSchemeNotifier.value;
    final palette = resolveGlobalPalette(scheme);
    if (!mounted) return;
    setState(() {
      _globalPrimary = palette.primary;
      _globalSecondary = palette.secondary;
      _globalAccent = palette.accent;
    });
  }

  void _onGlobalSchemeChanged() {
    _loadGlobalPalette();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || !AccountManager.hasActiveSession()) return;

      try {
        final onLessonCourses = await RCCourseApi.getOnLessonAndUpcomingExam();
        if (onLessonCourses != null && mounted) {
          if (_lastOnLessonCourses == null || _lastOnLessonCourses.toString() != onLessonCourses.toString()) {
            _lastOnLessonCourses = onLessonCourses;
            _loadCourses(onLessonCourses);
          }
        }
      } catch (e) {
        debugPrint('Periodic refresh error: $e');
      }
    });
  }

  Future<void> _loadCourses([Map<String, dynamic>? onLessonCourses]) async {
    setState(() {
      _isLoading = true;
    });

    if (!AccountManager.hasActiveSession()) {
      setState(() {
        _isLoading = false;
      });
      return; // 没有登录账号时不加载课程
    }

    try {
      List<Course>? coursesData;
      if (PlatformManager().isChaoxing) {
        coursesData =  await CXCourseApi.getCoursesList();
      } else if (PlatformManager().isRainClassroom) {
        coursesData =  await RCCourseApi.getCoursesList(onLessonCourses);
      } else if (PlatformManager().isTronclass) {
        coursesData = await TCCourseApi.getCoursesList();
        } else if (PlatformManager().isKetangpai) {
          coursesData = await KTCourseApi.getCoursesList();
      }

      if (coursesData != null && coursesData.isNotEmpty) {
        setState(() {
          _courses = coursesData!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _courses =  [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _courses = [];
        _isLoading = false;
      });
    }
  }

  Widget _buildTronclassEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: _globalPrimary,
            ),
            const SizedBox(height: 16),
            const Text(
              '畅课已接通，但当前暂无课程数据',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              '可以重新加载课程，或直接使用右上角扫码入口进入签到。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadCourses,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新加载'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScanPage(
                          onScanResult: handleScanContent,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('扫码签到'),
                ),
                OutlinedButton.icon(
                  onPressed: _openTronclassPortal,
                  icon: const Icon(Icons.language),
                  label: const Text('畅课门户'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTronclassPortal() async {
    if (!PlatformManager().isTronclass) {
      return;
    }

    var mode = await AppSettings.getString(
      AppSettings.tronclassPortalOpenModeKey,
      AppSettings.portalOpenModeExternalPreferred,
    );

    if (mode == AppSettings.portalOpenModeAskEveryTime && mounted) {
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择打开方式'),
          content: const Text('本次如何打开畅课门户？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, AppSettings.portalOpenModeEmbeddedPreferred);
              },
              child: const Text('内置门户'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, AppSettings.portalOpenModeExternalPreferred);
              },
              child: const Text('系统浏览器'),
            ),
          ],
        ),
      );
      mode = selected ?? AppSettings.portalOpenModeExternalPreferred;
    }

    if (defaultTargetPlatform == TargetPlatform.windows &&
        mode == AppSettings.portalOpenModeEmbeddedPreferred) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Windows 下已自动改为系统浏览器打开')),
        );
      }
      mode = AppSettings.portalOpenModeExternalPreferred;
    }

    if (mode == AppSettings.portalOpenModeExternalPreferred) {
      final opened = await launchUrl(
        Uri.parse(PlatformManager().tronclassBaseUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('系统浏览器打开失败')),
        );
      }
      return;
    }

    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录畅课账号')),
      );
      return;
    }

    final currentUser = AccountManager.getAccountById(currentUserId);
    final accountName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : currentUserId;

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassWebLoginPage(
          accountName: accountName,
          accountId: currentUserId,
          initialUrl: Uri.parse(PlatformManager().tronclassBaseUrl),
          initialMessage: '已进入畅课门户，可直接查看课程、公告和作业',
          autoCloseOnAuthSuccess: false,
        ),
      ),
    );
  }

  Widget _buildTronclassQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTronclassHeaderPanel() {
    final currentUser = AccountManager.getAccountById(AccountManager.currentSessionId ?? '');
    final userName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : '当前账号';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_globalPrimary, _globalSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _globalPrimary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '畅课工作台',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '欢迎你，$userName',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildTronclassQuickAction(
            icon: Icons.language,
            title: '畅课门户',
            subtitle: '打开 Web 门户，浏览课程与任务',
            color: _globalPrimary,
            onTap: _openTronclassPortal,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTronclassQuickAction(
                  icon: Icons.qr_code_scanner,
                  title: '扫码',
                  subtitle: '立即签到',
                  color: _globalAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScanPage(onScanResult: handleScanContent),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTronclassQuickAction(
                  icon: Icons.account_circle_outlined,
                  title: '账号',
                  subtitle: '管理登录状态',
                  color: _globalSecondary,
                  onTap: () {
                    Navigator.pushNamed(context, '/accounts');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTronclassCourseCard(Course course) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TronclassSignInPage(course: course),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _globalPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.class_outlined, color: _globalPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.teacher.isEmpty ? '未知教师' : course.teacher,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TronclassSignInPage(course: course),
                        ),
                      );
                    },
                    icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                    label: const Text('签到'),
                  ),
                ],
              ),
              if (course.schools != null || course.note != null) ...[
                const SizedBox(height: 10),
                Text(
                  course.schools ?? course.note ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> handleScanContent(String result) async {
    if (!AccountManager.hasActiveSession()){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('二维码内容'),
              content: SelectableText(result),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      });
      return;
    }
  
    if (result.startsWith('http')) {
      try {
        final uri = Uri.parse(result);
        final baseUrl = uri.origin + uri.path;
        final params = uri.queryParameters;
  
        // 判断是否为签到 URL
        if (baseUrl == 'https://mobilelearn.chaoxing.com/widget/sign/e') {
          if (!PlatformManager().isChaoxing) {
            await PlatformManager().setPlatform(PlatformType.chaoxing);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('自动切换平台为学习通')),
            );
          }
          if (!AccountManager.hasActiveSession()){
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('提示'),
                  content: const Text('没有可用账号'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('确定'),
                    ),
                  ],
                );
              },
            );
            return;
          }
  
          final activeId = params['id'];
          if (activeId != null) {
            final response = await ApiService.sendRequest(result, responseType: ResponseType.plain, allowRedirects: false);
            if (!mounted) return;
            final locationUrl = response.headers['location']?.first;
            // String? location = response.realUri.toString();

            // 重定向到 https://mobilelearn.chaoxing.com/newsign/preSign?
            // courseId=&classId=$classId&activePrimaryId=4000147729438&general=1&sys=1&ls=1&appType=15&uid=$uid&
            // rcode=SIGNIN%3Aaid%3D4000147729438%26source%3D15%26Code%3D4000147729438%26enc%3DE39EE73BB53907CC04850F4C6EE077B6
            final uri = Uri.parse(locationUrl!);
            final params = uri.queryParameters;

            final classId = params['classId'] ?? '';
            // final activePrimaryId = params['activePrimaryId'] ?? '';
            final decodedRcode = Uri.decodeComponent(params['rcode']!);
            RegExp encRegex = RegExp(r'enc=([^&\s]+)');
            Match? match = encRegex.firstMatch(decodedRcode);

            if (match != null) {
              final enc = match.group(1);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SignInPage(
                    active: Active(
                        type: 2,
                        id: activeId,
                        name: '二维码签到',
                        description: '',
                        startTime: 0,
                        url: '',
                        status: true,
                        extras: {},
                        signType: SignType.qrCode
                    ),
                    courseId: '',
                    classId: classId,
                    cpi: '',
                    enc: enc
                  ),
                ),
              );
            } else {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未找到 enc 参数')),
              );
            }
          }
        } else if (baseUrl == 'https://www.yuketang.cn/api/v3/lesson/check-in/dynamic-qr-code'){
          if (!PlatformManager().isRainClassroom) {
            await PlatformManager().setPlatform(PlatformType.rainClassroom);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('自动切换平台为雨课堂')),
            );
          }
          if (!AccountManager.hasActiveSession()){
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  content: const Text('没有可用账号'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('确定'),
                    ),
                  ],
                );
              },
            );
            return;
          }
  
          // https://www.yuketang.cn/api/v3/lesson/check-in/dynamic-qr-code?
          // c=fL5xO1crTr6AC1Re3BaUEurgVNpZL0zydLypc0f2m2A&t=1772409038563&s=B53F5736FCCAF827&v=2
  
            await _multiScan(result);
          } else if (params.containsKey('ticketid') &&
              params.containsKey('expire') &&
              params.containsKey('sign')) {
            if (!PlatformManager().isKetangpai) {
              await PlatformManager().setPlatform(PlatformType.ketangpai);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('自动切换平台为课堂派')),
              );
            }

            await _multiScan(result);
        } else {
          // 其他 URL 处理
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('扫描到链接'),
                  content: SelectableText(result),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                );
              },
            );
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL 解析失败：$e')),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描结果：$result')),
      );
    }
  }

  /// 为所有用户扫描
  Future<void> _multiScan(String qrCodeUrl) async {
    final isRainClassroom = PlatformManager().isRainClassroom;
    final isKetangpai = PlatformManager().isKetangpai;

    final allAccounts = AccountManager.getAllAccounts();
    final targetAccounts = allAccounts.where((user) {
      if (isRainClassroom) return user.isRainClassroom;
      if (isKetangpai) return user.isKetangpai;
      return true;
    }).toList();

    if (targetAccounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前平台没有可用账号进行签到'))
      );
      return;
    }
  
    setState(() {
      _isLoading = true;
    });
  
    int successCount = 0;
    final List<String> failedAccounts = [];
  
    final currentUserId = AccountManager.currentSessionId;
    for (final user in targetAccounts) {
      try {
        if (isRainClassroom) {
          AccountManager.setCurrentSessionTemp(user.uid);
          final status = await RCCourseApi.scan(qrCodeUrl);
          if (status == 0) {
            successCount++;
          } else if (status == 51203) {
            failedAccounts.add('${user.name} (动态二维码过期)');
          } else {
            failedAccounts.add('${user.name} (错误码：$status)');
          }
        } else if (isKetangpai) {
          if (user.token.isEmpty) {
            failedAccounts.add('${user.name} (token为空，请先登录)');
            continue;
          }

          final ok = await KTSignApi.scanToSign(qrCodeUrl, user.token);
          if (ok) {
            successCount++;
          } else {
            failedAccounts.add('${user.name} (签到失败)');
          }
        } else {
          failedAccounts.add('${user.name} (当前平台不支持批量扫码)');
        }
      } catch (e) {
        failedAccounts.add('${user.name} (异常：$e)');
      }
    }
    if (currentUserId != null && currentUserId.isNotEmpty) {
      AccountManager.setCurrentSessionTemp(currentUserId);
    }
  
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  
    _showMultiScanResult(successCount, targetAccounts.length, failedAccounts);
  }

  /// 显示所有签到结果
  void _showMultiScanResult(int successCount, int totalCount, List<String> failedAccounts) {
    String message = '签到完成！\n成功: $successCount/$totalCount';
    if (failedAccounts.isNotEmpty) {
      message += '\n\n失败账号:\n${failedAccounts.join('\n')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          successCount == totalCount ? '全部签到成功' : '部分失败',
          style: TextStyle(
            color: successCount == totalCount ? Colors.green : Colors.orange,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformManager().isWeizhuojiao) {
      return Scaffold(
        appBar: AppBar(title: const Text('课程')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  '微助教功能正在完善中',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '该入口已临时封禁，后续版本开放。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isTronclass = PlatformManager().isTronclass;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTronclass ? '畅课' : '课程'),
        backgroundColor: _globalPrimary,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: AppSettings.strictSecurityModeNotifier,
                builder: (context, strictMode, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          strictMode ? Icons.shield : Icons.shield_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          strictMode ? '严格' : '标准',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (isTronclass)
            IconButton(
              tooltip: '畅课门户',
              icon: const Icon(Icons.language),
              onPressed: _openTronclassPortal,
            ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScanPage(
                    onScanResult: handleScanContent,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isTronclass
          ? RefreshIndicator(
              onRefresh: _loadCourses,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTronclassHeaderPanel()),
                  if (_courses.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildTronclassEmptyState(context),
                    )
                  else
                    SliverList.builder(
                      itemCount: _courses.length,
                      itemBuilder: (context, index) {
                        final course = _courses[index];
                        return _buildTronclassCourseCard(course);
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCourses,
              child: _courses.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无课程数据',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _courses.length,
                      itemBuilder: (context, index) {
                        var course = _courses[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: InkWell(
                            onTap: () {
                              if (PlatformManager().isChaoxing) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CourseContentPage(
                                      courseId: course.courseId,
                                      courseName: course.name,
                                      classId: course.classId,
                                      cpi: course.cpi!,
                                    ),
                                  ),
                                );
                              } else if (PlatformManager().isRainClassroom) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PresentationPage(
                                      lessonId: course.lessonId!,
                                      title: course.name,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => KetangpaiCourseStructPage(course: course),
                                  ),
                                );
                              }
                            },
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Builder(
                                            builder: (context) {
                                              final title = course.name.trim();
                                              final firstChar =
                                                  title.isEmpty ? '课' : title.substring(0, 1);
                                              if (course.image.isNotEmpty) {
                                                return AvatarWidget(
                                                  imageUrl: course.image,
                                                  size: 50,
                                                  borderRadius: 6,
                                                  iconSize: 25,
                                                );
                                              }
                                              return Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      _globalPrimary,
                                                      _globalSecondary.withValues(alpha: 0.92),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    firstChar,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  course.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  course.teacher,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 5),
                                      if (course.note != null)
                                        Text(
                                          course.note!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (course.schools != null)
                                        Text(
                                          course.schools!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      if (course.beginDate != null && course.endDate != null)
                                        Text(
                                          '开课时间：${course.beginDate} 至 ${course.endDate}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 16,
                                  top: 0,
                                  bottom: 0,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppSettings.globalColorSchemeNotifier.removeListener(_onGlobalSchemeChanged);
    _accountChangeSubscription?.cancel();
    _platformChangeSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}