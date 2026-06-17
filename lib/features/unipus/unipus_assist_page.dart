import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'unipus_controller.dart';
import 'unipus_models.dart';

class UnipusAssistPage extends StatefulWidget {
  const UnipusAssistPage({super.key});

  @override
  State<UnipusAssistPage> createState() => _UnipusAssistPageState();
}

class _UnipusAssistPageState extends State<UnipusAssistPage> {
  final _controller = UnipusController();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userAgentController = TextEditingController();
  final _tutorialIdController = TextEditingController();
  final _reminderController = TextEditingController(text: '90');
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController(text: 'https://api.openai.com');
  final _modelController = TextEditingController(text: 'gpt-5-mini');

  bool _rememberPassword = false;
  bool _reviewMode = false;
  bool _autoOpenNext = true;
  bool _unfinishedFirst = true;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _controller.initialize().then((_) => _applyConfig(_controller.config));
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _userAgentController.dispose();
    _tutorialIdController.dispose();
    _reminderController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _applyConfig(UnipusAssistConfig config) {
    _usernameController.text = config.username;
    _passwordController.text = config.password;
    _userAgentController.text = config.userAgent;
    _tutorialIdController.text = config.tutorialId;
    _reminderController.text = config.reminderSeconds.toString();
    _apiKeyController.text = config.openAiApiKey;
    _baseUrlController.text = config.openAiBaseUrl;
    _modelController.text = config.openAiModel;
    _rememberPassword = config.rememberPassword;
    _reviewMode = config.reviewMode;
    _autoOpenNext = config.autoOpenNext;
    _unfinishedFirst = config.unfinishedFirst;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('U 校园辅助'),
        actions: [
          IconButton(
            tooltip: '复制任务清单',
            onPressed: _controller.queue.isEmpty ? null : _copyQueue,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: '复制日志',
            onPressed: _controller.logs.isEmpty ? null : _copyLogs,
            icon: const Icon(Icons.article_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusBanner(theme),
              const SizedBox(height: 12),
              _buildConfigPanel(theme),
              const SizedBox(height: 12),
              _buildAssistControlPanel(theme),
              const SizedBox(height: 12),
              _buildCoursePanel(theme),
              const SizedBox(height: 12),
              _buildQueuePanel(theme),
              const SizedBox(height: 12),
              _buildLogPanel(theme),
            ],
          ),
          if (_controller.busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ThemeData theme) {
    final error = _controller.error;
    final color = error == null
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final onColor = error == null
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error == null ? Icons.assistant_direction_outlined : Icons.error_outline,
              color: onColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error ??
                    '自动扫描课程树，生成确认式辅助队列。所有改变平台状态的动作都需要用户自己确认。',
                style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigPanel(ThemeData theme) {
    return _Section(
      title: '配置',
      icon: Icons.tune_outlined,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '账号',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入账号' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: _rememberPassword ? '密码（保存）' : '密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? '隐藏密码' : '显示密码',
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              obscureText: !_showPassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _tutorialIdController,
              decoration: const InputDecoration(
                labelText: '指定 tutorialId（可选）',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _reminderController,
              decoration: const InputDecoration(
                labelText: '提醒间隔（秒）',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed < 10) {
                  return '请输入不小于 10 的秒数';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _rememberPassword,
              onChanged: (value) => setState(() => _rememberPassword = value),
              title: const Text('保存密码'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reviewMode,
              onChanged: (value) => setState(() => _reviewMode = value),
              title: const Text('复习模式'),
              subtitle: const Text('包含已通过任务'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoOpenNext,
              onChanged: (value) => setState(() => _autoOpenNext = value),
              title: const Text('确认后自动打开下一项'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _unfinishedFirst,
              onChanged: (value) => setState(() => _unfinishedFirst = value),
              title: const Text('未完成优先'),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('高级配置'),
              childrenPadding: EdgeInsets.zero,
              children: [
                TextFormField(
                  controller: _userAgentController,
                  decoration: const InputDecoration(
                    labelText: 'User-Agent（可选）',
                    prefixIcon: Icon(Icons.web_asset_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI 兼容 API Key（可选）',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI 兼容 Base URL',
                    prefixIcon: Icon(Icons.link_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: '模型',
                    prefixIcon: Icon(Icons.psychology_outlined),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _controller.busy ? null : _saveConfig,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存配置'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _controller.busy ? null : _loginAndScan,
                    icon: const Icon(Icons.travel_explore_outlined),
                    label: const Text('登录并扫描'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistControlPanel(ThemeData theme) {
    final current = _controller.currentItem;
    return _Section(
      title: '确认推进',
      icon: Icons.play_circle_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current == null)
            const Text('暂无队列。请先登录并扫描课程树。')
          else ...[
            Text(
              current.courseName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(current.node.displayTitle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(
                  label: current.node.required ? '必修' : '普通',
                  color: current.node.required
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF64748B),
                ),
                _Tag(
                  label: current.node.passed ? '已通过' : '未通过',
                  color: current.node.passed
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                _Tag(
                  label:
                      '${_controller.currentIndex + 1}/${_controller.queue.length}',
                  color: const Color(0xFF0F766E),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: current == null || _controller.busy
                      ? null
                      : _controller.openCurrentItem,
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('打开当前项'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: current == null || _controller.busy
                      ? null
                      : _controller.confirmCurrentAndAdvance,
                  icon: const Icon(Icons.done_outline),
                  label: const Text('我已处理，下一项'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.busy ? null : _controller.startAssist,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    _controller.foregroundRunning ? '重启后台辅助' : '开始后台辅助',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: '停止后台辅助',
                onPressed: _controller.busy ? null : _controller.stopAssist,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: '忽略电池优化',
                onPressed: _controller.busy
                    ? null
                    : _controller.requestIgnoreBatteryOptimization,
                icon: const Icon(Icons.battery_saver_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoursePanel(ThemeData theme) {
    final totalCourses = _controller.courseBlocks.fold<int>(
      0,
      (sum, block) => sum + block.courses.length,
    );
    return _Section(
      title: '课程',
      icon: Icons.school_outlined,
      trailing: Text('$totalCourses 门'),
      child: _controller.courseBlocks.isEmpty
          ? const Text('扫描后会显示课程与班课。')
          : Column(
              children: [
                for (final block in _controller.courseBlocks)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(block.className.isEmpty ? '未命名班课' : block.className),
                    subtitle: Text(block.dateRange),
                    children: [
                      for (final course in block.courses)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(course.courseName.isEmpty ? '未命名课程' : course.courseName),
                          subtitle: Text(
                            [
                              if (course.status.isNotEmpty) course.status,
                              if (course.tutorialId.isNotEmpty) course.tutorialId,
                            ].join(' · '),
                          ),
                          leading: const Icon(Icons.menu_book_outlined),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _buildQueuePanel(ThemeData theme) {
    return _Section(
      title: '辅助队列',
      icon: Icons.format_list_numbered_outlined,
      trailing: Text('${_controller.pendingCount} 待确认'),
      child: _controller.queue.isEmpty
          ? const Text('暂无任务队列。')
          : Column(
              children: [
                for (var i = 0; i < _controller.queue.length; i++)
                  _QueueTile(
                    item: _controller.queue[i],
                    selected: i == _controller.currentIndex,
                    onTap: () => _controller.moveToQueueIndex(i),
                  ),
              ],
            ),
    );
  }

  Widget _buildLogPanel(ThemeData theme) {
    final logs = _controller.logs.reversed.take(20).toList();
    return _Section(
      title: '日志',
      icon: Icons.receipt_long_outlined,
      child: logs.isEmpty
          ? const Text('暂无日志。')
          : Column(
              children: [
                for (final log in logs)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _logIcon(log.level),
                      color: _logColor(log.level),
                    ),
                    title: Text(log.message),
                    subtitle: Text(_timeLabel(log.timestamp)),
                  ),
              ],
            ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    await _controller.saveConfig(_readConfig());
  }

  Future<void> _loginAndScan() async {
    if (!_formKey.currentState!.validate()) return;
    await _controller.saveConfig(_readConfig());
    await _controller.loginAndScan(captchaResolver: _showCaptchaDialog);
  }

  UnipusAssistConfig _readConfig() {
    return UnipusAssistConfig(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      rememberPassword: _rememberPassword,
      userAgent: _userAgentController.text.trim(),
      tutorialId: _tutorialIdController.text.trim(),
      reviewMode: _reviewMode,
      autoOpenNext: _autoOpenNext,
      unfinishedFirst: _unfinishedFirst,
      reminderSeconds: int.tryParse(_reminderController.text.trim()) ?? 90,
      openAiApiKey: _apiKeyController.text.trim(),
      openAiBaseUrl: _baseUrlController.text.trim().isEmpty
          ? 'https://api.openai.com'
          : _baseUrlController.text.trim(),
      openAiModel: _modelController.text.trim().isEmpty
          ? 'gpt-5-mini'
          : _modelController.text.trim(),
    );
  }

  Future<String> _showCaptchaDialog(UnipusCaptchaChallenge challenge) async {
    final inputController = TextEditingController();
    String? error;
    final bytes = Uint8List.fromList(challenge.imageBytes());
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final value = inputController.text.trim();
              if (value.isEmpty) {
                setDialogState(() => error = '请输入验证码');
                return;
              }
              Navigator.of(context).pop(value);
            }

            return AlertDialog(
              title: const Text('输入 U 校园验证码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      bytes,
                      width: 220,
                      height: 84,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                        width: 220,
                        height: 84,
                        child: Center(child: Text('验证码图片解析失败')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: inputController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      errorText: error,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('继续'),
                ),
              ],
            );
          },
        );
      },
    );
    inputController.dispose();
    if (result == null) {
      throw Exception('已取消验证码输入');
    }
    return result;
  }

  Future<void> _copyQueue() async {
    await Clipboard.setData(
      ClipboardData(text: _controller.exportQueueMarkdown()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制任务清单')),
      );
    }
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _controller.exportLogsText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制日志')),
      );
    }
  }

  IconData _logIcon(UnipusLogLevel level) {
    return switch (level) {
      UnipusLogLevel.success => Icons.check_circle_outline,
      UnipusLogLevel.warning => Icons.warning_amber_outlined,
      UnipusLogLevel.error => Icons.error_outline,
      UnipusLogLevel.info => Icons.info_outline,
    };
  }

  Color _logColor(UnipusLogLevel level) {
    return switch (level) {
      UnipusLogLevel.success => const Color(0xFF16A34A),
      UnipusLogLevel.warning => const Color(0xFFEA580C),
      UnipusLogLevel.error => const Color(0xFFDC2626),
      UnipusLogLevel.info => const Color(0xFF0F766E),
    };
  }

  String _timeLabel(DateTime time) {
    return '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final UnipusQueueItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: selected,
      onTap: onTap,
      leading: Icon(
        item.confirmed
            ? Icons.check_circle_outline
            : selected
            ? Icons.play_circle_outline
            : Icons.radio_button_unchecked,
        color: item.confirmed
            ? const Color(0xFF16A34A)
            : selected
            ? theme.colorScheme.primary
            : null,
      ),
      title: Text(item.node.displayTitle),
      subtitle: Text(item.courseName),
      trailing: Wrap(
        spacing: 6,
        children: [
          if (item.node.required)
            const _Tag(label: '必修', color: Color(0xFFEA580C)),
          _Tag(
            label: item.node.passed ? '已过' : '未过',
            color: item.node.passed
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
