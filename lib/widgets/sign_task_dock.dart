import 'package:flutter/material.dart';
import '../controllers/sign_task_controller.dart';
import '../controllers/account_context_controller.dart';
import '../session/sign_execution_context.dart';
import '../pages/courses.dart';
import 'account_context_header.dart';

class SignTaskDock extends StatelessWidget {
  const SignTaskDock({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SignTaskController.instance,
    builder: (context, _) {
      final tasks = SignTaskController.instance.tasks;
      if (tasks.isEmpty) return const SizedBox.shrink();
      final active = tasks.where((t) => t.running).toList();
      final task = active.isEmpty ? tasks.first : active.first;
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: ListTile(
          dense: true,
          minVerticalPadding: 8,
          leading: Icon(
            task.waiting
                ? Icons.touch_app_outlined
                : task.running
                ? Icons.sync
                : Icons.receipt_long_outlined,
          ),
          title: Text(
            task.waiting
                ? contextText(context, '签到等待处理', 'Check-in needs attention')
                : task.running
                ? contextText(context, '签到进行中', 'Checking in')
                : contextText(context, '查看签到结果', 'View check-in results'),
          ),
          subtitle: Text(
            '${platformTitle(context, task.identity.platform)} · ${task.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.keyboard_arrow_up),
          onTap: () => showSignTasks(context),
        ),
      );
    },
  );
}

Future<void> _openPlatformRecord(
  BuildContext context,
  SignExecutionContext identity,
) async {
  final navigator = Navigator.of(context);
  final controller = AccountContextController.instance;
  await controller.select(
    identity.platform,
    accountId: identity.account?.uid,
    server: identity.server,
    tronclassBaseUrl: identity.tronclassBaseUrl,
    ketangpaiBaseUrl: identity.ketangpaiBaseUrl,
  );
  if (!context.mounted || controller.error != null) return;
  navigator.pop();
  await navigator.push(MaterialPageRoute(builder: (_) => const CoursesPage()));
}

Future<void> showSignTasks(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: ListenableBuilder(
      listenable: SignTaskController.instance,
      builder: (context, _) => Column(
        children: [
          ListTile(
            title: Text(
              contextText(context, '签到任务', 'Check-in tasks'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: IconButton(
              tooltip: contextText(context, '收起', 'Minimize'),
              icon: const Icon(Icons.expand_more),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final task in SignTaskController.instance.tasks)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${platformTitle(context, task.identity.platform)} · ${task.label}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SignIdentityLabel(identity: task.identity),
                        if (task.accounts.isNotEmpty)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              contextText(
                                context,
                                '${task.accounts.length} 个签到账号',
                                '${task.accounts.length} check-in accounts',
                              ),
                            ),
                            children: [
                              for (final account in task.accounts)
                                ListTile(title: Text(account)),
                            ],
                          ),
                        if (task.running && !task.waiting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          ),
                        for (final message in task.messages)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(message),
                          ),
                        if (task.error != null)
                          Text(
                            contextText(
                              context,
                              '结果未确认，请先查看平台签到记录。',
                              'Outcome unconfirmed. Check the platform attendance record.',
                            ),
                          ),
                        if (!task.running && task.queryResult != null)
                          OutlinedButton.icon(
                            onPressed: task.querying ? null : task.query,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              task.querying
                                  ? contextText(context, '正在查询…', 'Checking…')
                                  : contextText(
                                      context,
                                      '查询平台结果',
                                      'Check platform result',
                                    ),
                            ),
                          ),
                        if (!task.running && task.queryResult == null)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              contextText(
                                context,
                                '打开对应账号的课程核实结果',
                                'Open account courses to verify results',
                              ),
                            ),
                            children: [
                              for (final identity
                                  in task.resultContexts.isEmpty
                                      ? [task.identity]
                                      : task.resultContexts)
                                ListTile(
                                  title: Text(
                                    identity.account?.name ??
                                        contextText(
                                          context,
                                          '选择账号',
                                          'Select account',
                                        ),
                                  ),
                                  subtitle: Text(
                                    Uri.parse(identity.endpoint).host,
                                  ),
                                  trailing: const Icon(Icons.open_in_new),
                                  onTap: () =>
                                      _openPlatformRecord(context, identity),
                                ),
                            ],
                          ),
                        if (task.waiting)
                          Wrap(
                            spacing: 8,
                            children: [
                              if (task.challenge != null)
                                FilledButton(
                                  onPressed: () {
                                    final navigator = Navigator.of(context);
                                    navigator.pop();
                                    task.resolveChallenge(navigator.context);
                                  },
                                  child: Text(
                                    contextText(context, '完成验证', 'Verify'),
                                  ),
                                ),
                              if (task.openSettings != null)
                                OutlinedButton(
                                  onPressed: task.openSettings,
                                  child: Text(
                                    contextText(
                                      context,
                                      '打开网络设置',
                                      'Network settings',
                                    ),
                                  ),
                                ),
                              if (task.challenge == null)
                                FilledButton(
                                  onPressed: () => task.respond(true),
                                  child: Text(
                                    contextText(context, '已处理，继续', 'Continue'),
                                  ),
                                ),
                              TextButton(
                                onPressed: () => task.respond(false),
                                child: Text(
                                  contextText(context, '跳过该账号', 'Skip account'),
                                ),
                              ),
                            ],
                          ),
                        const Divider(height: 24),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: SignTaskController.instance.dismissCompleted,
            child: Text(
              contextText(context, '收起已结束任务', 'Dismiss finished tasks'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  ),
);
