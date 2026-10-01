import 'package:flutter/material.dart';
import '../controllers/account_context_controller.dart';
import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/sign_mode_settings.dart';
import '../session/sign_execution_context.dart';

String contextText(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : zh;

String platformTitle(BuildContext context, PlatformType platform) =>
    Localizations.localeOf(context).languageCode != 'en'
    ? SignModeSettings.platformLabel(platform)
    : switch (platform) {
        PlatformType.chaoxing => 'Chaoxing',
        PlatformType.rainClassroom => 'Rain',
        PlatformType.tronclass => 'TronClass',
        PlatformType.ketangpai => 'Ketangpai',
        PlatformType.weizhuojiao => 'Weizhuojiao',
      };

class AccountContextHeader extends StatelessWidget {
  const AccountContextHeader({
    super.key,
    required this.platform,
    required this.account,
    required this.onPlatform,
    required this.onAccount,
    required this.site,
    this.switching = false,
    this.error,
    this.onSite,
  });
  final PlatformType platform;
  final User? account;
  final ValueChanged<PlatformType> onPlatform;
  final VoidCallback onAccount;
  final VoidCallback? onSite;
  final String site;
  final bool switching;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in PlatformType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Semantics(
                    selected: value == platform,
                    child: TextButton(
                      key: ValueKey('platform-${value.name}'),
                      onPressed: () => onPlatform(value),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: value == platform
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                        backgroundColor: value == platform
                            ? colors.primaryContainer
                            : null,
                      ),
                      child: Text(platformTitle(context, value)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const ValueKey('current-account'),
            minVerticalPadding: 12,
            onTap: switching ? null : onAccount,
            leading: CircleAvatar(
              backgroundColor: colors.primaryContainer,
              child: Icon(
                account == null
                    ? Icons.person_add_outlined
                    : Icons.person_outline,
                color: colors.onPrimaryContainer,
              ),
            ),
            title: Text(
              account?.name ??
                  contextText(context, '选择或登录账号', 'Choose an account'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              switching
                  ? contextText(context, '正在切换…', 'Switching…')
                  : account == null
                  ? contextText(context, '登录后开始签到', 'Sign in to check in')
                  : '${account!.studentId?.trim().isNotEmpty == true ? account!.studentId!.trim() : account!.uid} · ${contextText(context, '当前账号', 'Current account')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: switching
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.unfold_more_rounded),
          ),
        ),
        if (site.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onSite,
              icon: const Icon(Icons.public, size: 16),
              label: Text(site, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error!, style: TextStyle(color: colors.error)),
          ),
      ],
    );
  }
}

Future<User?> showAccountPicker(
  BuildContext context, {
  PlatformType? platform,
  String? site,
}) async {
  final selectedPlatform = platform ?? PlatformManager().currentPlatform;
  return showModalBottomSheet<User>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AccountPicker(platform: selectedPlatform, site: site),
  );
}

class _AccountPicker extends StatefulWidget {
  const _AccountPicker({required this.platform, this.site});
  final PlatformType platform;
  final String? site;
  @override
  State<_AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends State<_AccountPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final accounts = AccountManager.getAccountsForPlatform(widget.platform)
        .where(
          (user) => '${user.name} ${user.uid} ${user.studentId ?? ''}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    final selected = AccountManager.currentSessionForPlatform(widget.platform);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    MediaQuery.paddingOf(context).top -
                    80)
                .clamp(180.0, MediaQuery.sizeOf(context).height * .7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              platformTitle(context, widget.platform),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.site?.isNotEmpty == true) Text(widget.site!),
            const SizedBox(height: 16),
            TextField(
              autofocus: false,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: contextText(
                  context,
                  '搜索姓名或账号',
                  'Search name or account',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: accounts.isEmpty
                  ? Center(
                      child: Text(
                        contextText(context, '没有匹配的账号', 'No matching accounts'),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final user = accounts[index];
                        final expired =
                            user.credentialExpiry != null &&
                            user.credentialExpiry! * 1000 <
                                DateTime.now().millisecondsSinceEpoch;
                        return ListTile(
                          title: Text(user.name),
                          subtitle: Text(
                            '${user.studentId?.trim().isNotEmpty == true ? user.studentId!.trim() : user.uid} · ${expired ? contextText(context, '会话已到期', 'Session expired') : contextText(context, '已保存账号', 'Saved account')}',
                          ),
                          trailing: user.uid == selected
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: () => Navigator.pop(context, user),
                        );
                      },
                    ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(
                contextText(
                  context,
                  '添加账号 / 重新登录',
                  'Add account / Sign in again',
                ),
              ),
              onPressed: () async {
                final navigator = Navigator.of(context);
                final platform = widget.platform;
                navigator.pop();
                await AccountContextController.instance.select(platform);
                if (navigator.mounted &&
                    AccountContextController.instance.error == null) {
                  navigator.pushNamed('/accounts');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> selectAccountFromSheet(
  BuildContext context, {
  PlatformType? platform,
}) async {
  final selectedPlatform = platform ?? PlatformManager().currentPlatform;
  final user = await showAccountPicker(context, platform: selectedPlatform);
  if (user != null) {
    await AccountContextController.instance.select(
      selectedPlatform,
      accountId: user.uid,
    );
  }
}

class SignIdentityLabel extends StatelessWidget {
  const SignIdentityLabel({super.key, required this.identity});
  final SignExecutionContext identity;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: false,
    leading: const Icon(Icons.verified_user_outlined),
    title: Text(
      '${platformTitle(context, identity.platform)} · ${identity.account?.name ?? contextText(context, '未选择账号', 'No account')}',
    ),
    subtitle: Text(
      '${identity.account?.studentId ?? identity.account?.uid ?? ''} · ${Uri.parse(identity.endpoint).host}',
    ),
  );
}

Future<List<User>?> showSignAccountSelection(
  BuildContext context,
  SignExecutionContext identity,
) {
  final users = AccountManager.getAccountsForPlatform(identity.platform);
  final selected = <String>{
    if (identity.account != null) identity.account!.uid,
  };
  return showModalBottomSheet<List<User>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          children: [
            SignIdentityLabel(identity: identity),
            Expanded(
              child: ListView(
                children: [
                  for (final user in users)
                    CheckboxListTile(
                      title: Text(user.name),
                      subtitle: Text(user.studentId ?? user.uid),
                      value: selected.contains(user.uid),
                      onChanged: (value) => update(() {
                        value == true
                            ? selected.add(user.uid)
                            : selected.remove(user.uid);
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        users.where((u) => selected.contains(u.uid)).toList(),
                      ),
                child: Text(
                  contextText(
                    context,
                    '使用 ${selected.length} 个账号签到',
                    'Check in with ${selected.length} accounts',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showSignModePicker(
  BuildContext context,
  PlatformType platform,
) async {
  var mode = await SignModeSettings.getMode(platform);
  var selected = await SignModeSettings.getSelectedAccountIds(platform);
  if (!context.mounted) return;
  final users = AccountManager.getAccountsForPlatform(platform);
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ListTile(
                title: Text(
                  contextText(context, '签到账号与模式', 'Check-in accounts & mode'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final value in SignAccountMode.values)
                ListTile(
                  title: Text(
                    contextText(
                      context,
                      SignModeSettings.labelOf(value),
                      switch (value) {
                        SignAccountMode.manualCurrent => 'Current account',
                        SignAccountMode.savedPlatformSelection =>
                          'Saved account selection',
                        SignAccountMode.perRunSelection =>
                          'Choose for each check-in',
                      },
                    ),
                  ),
                  subtitle: Text(
                    contextText(
                      context,
                      SignModeSettings.descriptionOf(value),
                      switch (value) {
                        SignAccountMode.manualCurrent =>
                          'Use the account selected on the courses page.',
                        SignAccountMode.savedPlatformSelection =>
                          'Use the checked accounts below with the existing direct submission policy.',
                        SignAccountMode.perRunSelection =>
                          'Choose accounts in the check-in page; retain the existing network steps.',
                      },
                    ),
                  ),
                  trailing: value == mode
                      ? const Icon(Icons.check_circle)
                      : const Icon(Icons.circle_outlined),
                  onTap: () async {
                    update(() => mode = value);
                    await SignModeSettings.setMode(platform, value);
                  },
                ),
              if (mode == SignAccountMode.savedPlatformSelection) ...[
                const Divider(),
                ListTile(
                  title: Text(
                    contextText(
                      context,
                      '已选 ${selected.length} 个账号',
                      '${selected.length} accounts selected',
                    ),
                  ),
                ),
                for (final user in users)
                  CheckboxListTile(
                    title: Text(user.name),
                    subtitle: Text(user.studentId ?? user.uid),
                    value: selected.contains(user.uid),
                    onChanged: (checked) async {
                      update(() {
                        selected = {...selected};
                        checked == true
                            ? selected.add(user.uid)
                            : selected.remove(user.uid);
                      });
                      await SignModeSettings.setSelectedAccountIds(
                        platform,
                        selected,
                      );
                    },
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}
