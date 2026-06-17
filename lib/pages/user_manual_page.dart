import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accounts.dart';
import 'courses.dart';
import 'file_tools_page.dart';
import 'material_search_page.dart';
import 'settings.dart';
import 'study_center_page.dart';
import 'todos_page.dart';
import 'tools_page.dart';

class UserManualPage extends StatefulWidget {
  const UserManualPage({super.key, this.initialSectionId});

  final String? initialSectionId;

  @override
  State<UserManualPage> createState() => _UserManualPageState();
}

class _UserManualPageState extends State<UserManualPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<UserManualSection> get _visibleSections {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return userManualSections;
    return userManualSections.where((section) {
      final haystack = [
        section.title,
        section.summary,
        ...section.steps,
        ...section.tips,
        ...section.faqs,
      ].join('\n').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final initialSectionId = widget.initialSectionId;
    if (initialSectionId != null && initialSectionId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToSection(initialSectionId);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _jumpToSection(String id) {
    final index = _visibleSections.indexWhere((section) => section.id == id);
    if (index < 0) return;
    final target = 330.0 + index * 260.0;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _copyTroubleshootingChecklist() async {
    const text = '''
GUETer 排障反馈清单
1. 说明当前使用的平台：学习通 / 雨课堂 / 畅课 / 课堂派 / OpenList。
2. 说明操作入口：课程、待办、资料、工具、复习卡或插件。
3. 说明失败时间、课程名、活动类型和错误提示。
4. 先在设置页执行“一键修复常见问题”和健康检查。
5. 如仍失败，复制诊断包并附上复现步骤。
''';
    await Clipboard.setData(const ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('排障清单已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final sections = _visibleSections;
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用说明书'),
        actions: [
          IconButton(
            tooltip: '复制排障清单',
            onPressed: _copyTroubleshootingChecklist,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _ManualHero(onCopyChecklist: _copyTroubleshootingChecklist),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              labelText: '搜索说明书',
              hintText: '例如：登录、签到、资料、复习卡、插件、排障',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          _QuickJumpPanel(onJump: _jumpToSection),
          const SizedBox(height: 12),
          _ManualNavigationPanel(onOpen: _openPage),
          const SizedBox(height: 12),
          if (sections.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('没有匹配的说明内容，请换一个关键词。'),
              ),
            )
          else
            ...sections.map(
              (section) =>
                  _ManualSectionCard(section: section, onOpen: _openPage),
            ),
        ],
      ),
    );
  }

  Future<void> _openPage(ManualAction action) async {
    final builder = switch (action.target) {
      ManualTarget.accounts => (_) => const AccountsPage(),
      ManualTarget.courses => (_) => CoursesPage(key: coursesPageKey),
      ManualTarget.todos => (_) => const TodosPage(),
      ManualTarget.materials => (_) => const MaterialSearchPage(),
      ManualTarget.tools => (_) => const ToolsPage(),
      ManualTarget.fileTools => (_) => const FileToolsPage(),
      ManualTarget.studyCards => (_) => const StudyCenterPage(),
      ManualTarget.settings => (_) => const SettingsPage(),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }
}

class UserManualSection {
  const UserManualSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.summary,
    required this.steps,
    required this.tips,
    required this.faqs,
    this.actions = const <ManualAction>[],
  });

  final String id;
  final String title;
  final IconData icon;
  final String summary;
  final List<String> steps;
  final List<String> tips;
  final List<String> faqs;
  final List<ManualAction> actions;
}

class ManualAction {
  const ManualAction(this.label, this.icon, this.target);

  final String label;
  final IconData icon;
  final ManualTarget target;
}

enum ManualTarget {
  accounts,
  courses,
  todos,
  materials,
  tools,
  fileTools,
  studyCards,
  settings,
}

const List<UserManualSection> userManualSections = <UserManualSection>[
  UserManualSection(
    id: 'quick-start',
    title: '首次使用流程',
    icon: Icons.rocket_launch_outlined,
    summary: '第一次使用建议按“选平台、登账号、看课程、跑预检、再使用工具”的顺序完成。',
    steps: [
      '打开账号页，先确认要使用的平台，再添加对应平台账号。',
      '登录成功后进入课程页刷新课程列表，确认课程、活动和资料能正常读取。',
      '需要签到前，先在设置页运行批量签到预检，减少定位、Cookie、平台状态导致的失败。',
      '资料、文件工具、复习卡属于本地能力，不依赖课程绑定，可以先用测试文件熟悉流程。',
    ],
    tips: ['不同平台账号互不影响，切换平台前先确认当前页面标题和账号状态。', '首次登录后如果课程为空，先刷新课程，再检查账号是否过期。'],
    faqs: [
      '问：需要一直后台运行吗？答：不需要。待办提醒等能力会尽量使用本地状态，平台接口异常时需要手动刷新。',
      '问：账号会上传吗？答：不会上传到本项目服务器，账号和会话按本地加密存储策略处理。',
    ],
    actions: [
      ManualAction(
        '打开账号',
        Icons.account_circle_outlined,
        ManualTarget.accounts,
      ),
      ManualAction('打开课程', Icons.school_outlined, ManualTarget.courses),
      ManualAction('打开设置', Icons.settings_outlined, ManualTarget.settings),
    ],
  ),
  UserManualSection(
    id: 'login',
    title: '账号与登录',
    icon: Icons.verified_user_outlined,
    summary: '账号页负责各平台登录、会话维护和基础账号管理。遇到登录异常时优先看平台、验证码和会话状态。',
    steps: [
      '进入账号页，选择学习通、雨课堂、畅课、课堂派等平台后再登录。',
      '畅课建议优先使用系统浏览器登录，并尽量复用已有会话。',
      '遇到验证码、多因子认证或二维码登录时，按页面提示完成一次真实验证。',
      '登录后返回账号页确认当前账号显示正常，再进入课程或待办页刷新数据。',
    ],
    tips: [
      '不要频繁重复提交验证码或短信码，平台可能限制请求频率。',
      '如果同一平台多个账号混用，先在账号页确认当前账号，再执行签到或查看课程。',
    ],
    faqs: [
      '问：登录突然失效怎么办？答：先重新打开账号页刷新状态，再按设置页的修复建议处理。',
      '问：为什么不同平台状态不一致？答：各平台 Cookie、Token、登录流程不同，应用会隔离处理。',
    ],
    actions: [
      ManualAction(
        '打开账号',
        Icons.account_circle_outlined,
        ManualTarget.accounts,
      ),
      ManualAction('打开设置', Icons.settings_outlined, ManualTarget.settings),
    ],
  ),
  UserManualSection(
    id: 'courses-sign',
    title: '课程与签到',
    icon: Icons.event_available_outlined,
    summary: '课程页用于查看课程、活动、章节和平台入口；签到前先确认账号、课程和定位权限。',
    steps: [
      '进入课程页后刷新当前平台课程。',
      '打开课程详情查看活动、章节、作业或资料入口。',
      '签到前确认活动类型：普通、二维码、位置、数字或课堂派/畅课专项签到。',
      '需要定位时先授权系统定位权限，再确认地图或定位点是否正确。',
    ],
    tips: ['二维码和位置签到通常有时间窗口，先确认老师是否已经开始签到。', '批量签到前建议先运行预检，避免多个账号同时失败。'],
    faqs: [
      '问：签到失败是否会自动重试？答：不同平台策略不同，失败后先看错误提示，不建议盲目重复提交。',
      '问：课程详情打不开怎么办？答：先检查账号登录态，再切换网络或重新进入课程页。',
    ],
    actions: [
      ManualAction('打开课程', Icons.school_outlined, ManualTarget.courses),
      ManualAction('打开设置', Icons.settings_outlined, ManualTarget.settings),
    ],
  ),
  UserManualSection(
    id: 'todos',
    title: '待办与提醒',
    icon: Icons.check_circle_outline,
    summary: '待办页聚合各平台作业、考试、问卷和活动提醒，适合每天打开一次检查。',
    steps: [
      '进入待办页后刷新所有平台待办。',
      '按截止时间查看作业、考试、问卷和课程活动。',
      '打开单条待办查看详情；需要跳转平台时按页面提示进入对应平台页面。',
      '如果提醒不准，先刷新待办，再检查系统通知权限。',
    ],
    tips: ['平台接口变动时，待办可能短时间缺失，以平台官方页面为准。', '考试类待办请提前核对时间，不要等到截止前才刷新。'],
    faqs: [
      '问：待办为什么和平台不一致？答：可能是缓存、登录态或平台接口延迟导致。',
      '问：能否自动提交作业？答：说明书首版只覆盖查看与提醒，不鼓励自动提交类操作。',
    ],
    actions: [
      ManualAction('打开待办', Icons.check_circle_outline, ManualTarget.todos),
    ],
  ),
  UserManualSection(
    id: 'materials-review',
    title: '资料到复习卡',
    icon: Icons.style_outlined,
    summary: '资料知识库可以记录资料、搜索内容、预览文件，并把片段批量生成复习卡。',
    steps: [
      '进入资料页，先重建索引，应用会索引云盘下载、离线包、文件工具输出和复习卡来源。',
      '使用关键词搜索文件名、路径和正文片段。',
      '搜索结果可单条生成复习卡，也可以多选后批量生成复习卡。',
      '文本预览和 OCR 文本可以拆分成多张候选复习卡，保存前可以选择卡组和条目。',
      '在复习中心查看到期卡片，带来源的卡片可以打开原资料。',
    ],
    tips: ['首轮不做 PDF 精确高亮，PDF 仍以预览和来源回跳为主。', '应用不移动、不重命名你的资料文件，只记录本地路径和来源信息。'],
    faqs: [
      '问：文件缺失怎么办？答：资料库会标记缺失，不会删除记录；把文件放回原路径后再刷新。',
      '问：复习卡背面太长怎么办？答：批量生成前可以取消不合适条目，后续可在复习中心删除。',
    ],
    actions: [
      ManualAction(
        '打开资料',
        Icons.manage_search_outlined,
        ManualTarget.materials,
      ),
      ManualAction('复习中心', Icons.style_outlined, ManualTarget.studyCards),
    ],
  ),
  UserManualSection(
    id: 'file-tools',
    title: '文件工具',
    icon: Icons.folder_copy_outlined,
    summary: '文件工具提供 ZIP 解压/打包、重命名、输出历史、分享、查重和输出资料入库。',
    steps: [
      '进入工具页后打开文件工具。',
      '选择 ZIP 可先预览条目，确认安全条目后再解压。',
      '打包文件时可设置压缩包名称和压缩级别。',
      '工具输出成功后会记录到历史，并写入资料收件箱，便于后续搜索和复习。',
    ],
    tips: ['遇到不安全 ZIP 路径时不要强行解压。', '大文件分享前可以先打开所在目录确认文件是否生成完整。'],
    faqs: [
      '问：文件工具会覆盖原文件吗？答：输出优先写到工具输出目录，具体操作前仍要看页面提示。',
      '问：能清理重复文件吗？答：可以从资料状态或文件工具入口进入查重清理。',
    ],
    actions: [
      ManualAction('打开工具', Icons.apps_outlined, ManualTarget.tools),
      ManualAction('文件工具', Icons.folder_copy_outlined, ManualTarget.fileTools),
    ],
  ),
  UserManualSection(
    id: 'plugins',
    title: '插件与扩展',
    icon: Icons.extension_outlined,
    summary: '插件系统用于声明式 Mod 扩展，适合添加安全受控的工具入口和文件动作。',
    steps: [
      '进入工具页或设置页中的插件管理。',
      '查看已安装插件，确认插件来源、清单和启用状态。',
      '使用模板创建插件时，先阅读生成的 README，再手动启用。',
      '插件动作会受清单能力限制，不会直接执行任意 Dart、脚本或原生命令。',
    ],
    tips: ['不要启用来源不明的插件。', '插件说明应写清楚入口用途、需要的权限和数据范围。'],
    faqs: [
      '问：插件能读取账号密码吗？答：声明式插件不应读取账号、Cookie、Token 或私有服务配置。',
      '问：插件打不开怎么办？答：先检查 plugin.json 是否有效，再看插件管理页提示。',
    ],
    actions: [
      ManualAction('打开工具', Icons.apps_outlined, ManualTarget.tools),
      ManualAction('打开设置', Icons.settings_outlined, ManualTarget.settings),
    ],
  ),
  UserManualSection(
    id: 'faq',
    title: '常见问题',
    icon: Icons.help_outline,
    summary: '这里汇总最常见的使用疑问：账号、网络、权限、资料、复习卡和通知。',
    steps: [
      '先确认问题发生在哪个入口：账号、课程、待办、资料、工具、复习卡或插件。',
      '记录错误提示、操作时间、平台名称和当前账号。',
      '尝试刷新、重新登录、切换网络、检查权限。',
      '仍无法解决时复制排障清单，并生成诊断包反馈。',
    ],
    tips: ['平台接口变化时，局部功能可能短时间异常。', '学校网络、VPN、代理、系统 WebView 都可能影响登录和课程加载。'],
    faqs: [
      '问：为什么某个按钮灰色？答：通常是缺少输入、当前平台不支持或前置状态未完成。',
      '问：为什么资料搜不到？答：先重建索引，确认文件类型支持且文件未缺失。',
      '问：为什么复习卡没有来源？答：手动创建的卡片默认没有来源，从资料、预览、OCR 生成的卡片会保留来源。',
    ],
    actions: [
      ManualAction('打开设置', Icons.settings_outlined, ManualTarget.settings),
    ],
  ),
  UserManualSection(
    id: 'privacy',
    title: '隐私与合规',
    icon: Icons.privacy_tip_outlined,
    summary: '本应用是学习辅助工具，不是任何教学平台或学校的官方客户端。使用前请确认你有合法访问权限。',
    steps: [
      '只登录你本人有权使用的账号。',
      '不要把账号、验证码、诊断包随意发给陌生人。',
      '涉及签到、作业、考试的功能，请遵守学校和平台规则。',
      '如平台规则或老师要求与工具能力冲突，以平台和学校要求为准。',
    ],
    tips: ['账号和会话按本地加密存储策略处理，不提供本项目服务器云同步。', '诊断反馈前先检查是否包含个人敏感信息。'],
    faqs: ['问：这是官方客户端吗？答：不是。', '问：能保证所有功能一直可用吗？答：不能，平台策略、接口和网络环境都会影响功能。'],
    actions: [
      ManualAction('打开设置', Icons.settings_outlined, ManualTarget.settings),
    ],
  ),
  UserManualSection(
    id: 'troubleshooting',
    title: '故障排查',
    icon: Icons.build_circle_outlined,
    summary: '排障优先顺序：看提示、确认账号、刷新状态、检查权限、运行修复、生成诊断包。',
    steps: [
      '复制或截图页面错误提示。',
      '确认当前平台、账号、课程和网络环境。',
      '在设置页执行一键修复常见问题和平台健康检查。',
      '如果问题可复现，记录最短复现路径。',
      '反馈时附上诊断包、平台、账号类型、课程名和发生时间。',
    ],
    tips: ['不要只反馈“不能用”，至少说明入口和错误提示。', '如果是登录问题，优先说明是否涉及验证码、短信、多因子认证或二维码。'],
    faqs: [
      '问：诊断包有什么用？答：它能帮助定位平台、请求、权限和本地状态问题。',
      '问：修复后还失败怎么办？答：换网络、重登账号，再附诊断信息反馈。',
    ],
    actions: [
      ManualAction('打开设置', Icons.settings_outlined, ManualTarget.settings),
    ],
  ),
];

class _ManualHero extends StatelessWidget {
  const _ManualHero({required this.onCopyChecklist});

  final VoidCallback onCopyChecklist;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '使用说明书',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '从登录、课程、签到、待办，到资料知识库、文件工具、复习卡和插件扩展，这里按实际使用流程整理了完整操作说明。',
            style: TextStyle(color: scheme.onPrimaryContainer, height: 1.45),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCopyChecklist,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('复制排障清单'),
          ),
        ],
      ),
    );
  }
}

class _QuickJumpPanel extends StatelessWidget {
  const _QuickJumpPanel({required this.onJump});

  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    const items = <MapEntry<String, String>>[
      MapEntry('quick-start', '首次使用流程'),
      MapEntry('materials-review', '资料到复习卡'),
      MapEntry('troubleshooting', '登录/签到排障'),
      MapEntry('privacy', '隐私与合规'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return ActionChip(
          avatar: const Icon(Icons.arrow_downward_rounded, size: 18),
          label: Text(item.value),
          onPressed: () => onJump(item.key),
        );
      }).toList(),
    );
  }
}

class _ManualNavigationPanel extends StatelessWidget {
  const _ManualNavigationPanel({required this.onOpen});

  final ValueChanged<ManualAction> onOpen;

  @override
  Widget build(BuildContext context) {
    const actions = <ManualAction>[
      ManualAction('账号', Icons.account_circle_outlined, ManualTarget.accounts),
      ManualAction('课程', Icons.school_outlined, ManualTarget.courses),
      ManualAction('待办', Icons.check_circle_outline, ManualTarget.todos),
      ManualAction('资料', Icons.manage_search_outlined, ManualTarget.materials),
      ManualAction('工具', Icons.apps_outlined, ManualTarget.tools),
      ManualAction('设置', Icons.settings_outlined, ManualTarget.settings),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '常用入口',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map((action) {
                return OutlinedButton.icon(
                  onPressed: () => onOpen(action),
                  icon: Icon(action.icon, size: 18),
                  label: Text(action.label),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSectionCard extends StatelessWidget {
  const _ManualSectionCard({required this.section, required this.onOpen});

  final UserManualSection section;
  final ValueChanged<ManualAction> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: section.id == 'quick-start',
        leading: Icon(section.icon),
        title: Text(section.title),
        subtitle: Text(section.summary),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _ManualTextGroup(title: '操作步骤', items: section.steps, ordered: true),
          _ManualTextGroup(title: '注意事项', items: section.tips),
          _ManualTextGroup(title: '常见问题', items: section.faqs),
          if (section.actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: section.actions.map((action) {
                  return FilledButton.tonalIcon(
                    onPressed: () => onOpen(action),
                    icon: Icon(action.icon, size: 18),
                    label: Text(action.label),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualTextGroup extends StatelessWidget {
  const _ManualTextGroup({
    required this.title,
    required this.items,
    this.ordered = false,
  });

  final String title;
  final List<String> items;
  final bool ordered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...items.indexed.map((entry) {
            final prefix = ordered ? '${entry.$1 + 1}.' : '•';
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 28, child: Text(prefix)),
                  Expanded(
                    child: Text(entry.$2, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
