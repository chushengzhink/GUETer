import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../platform.dart';
import 'account.dart';

enum SignAccountMode { manualCurrent, savedPlatformSelection, perRunSelection }

enum SignSubmitNetworkPolicy { direct, reconnect }

class SignModeResolution {
  const SignModeResolution({
    required this.mode,
    required this.users,
    required this.networkPolicy,
    this.message,
  });

  final SignAccountMode mode;
  final List<User> users;
  final SignSubmitNetworkPolicy networkPolicy;
  final String? message;

  bool get hasUsers => users.isNotEmpty;
}

class SignModeSettings {
  static const String _modePrefix = 'sign_mode';
  static const String _selectedPrefix = 'sign_selected_accounts';

  static String platformKey(PlatformType platform) {
    return switch (platform) {
      PlatformType.chaoxing => 'chaoxing',
      PlatformType.rainClassroom => 'rainclassroom',
      PlatformType.tronclass => 'tronclass',
      PlatformType.ketangpai => 'ketangpai',
      PlatformType.weizhuojiao => 'weizhuojiao',
    };
  }

  static String platformLabel(PlatformType platform) {
    return switch (platform) {
      PlatformType.chaoxing => '学习通',
      PlatformType.rainClassroom => '雨课堂',
      PlatformType.tronclass => '畅课',
      PlatformType.ketangpai => '课堂派',
      PlatformType.weizhuojiao => '微助教',
    };
  }

  static bool supportsPlatform(PlatformType platform) {
    return platform != PlatformType.weizhuojiao;
  }

  static String labelOf(SignAccountMode mode) {
    return switch (mode) {
      SignAccountMode.manualCurrent => '手动切换',
      SignAccountMode.savedPlatformSelection => '平台所选（直接批量）',
      SignAccountMode.perRunSelection => '每次选择（换网批量）',
    };
  }

  static String descriptionOf(SignAccountMode mode) {
    return switch (mode) {
      SignAccountMode.manualCurrent => '每次签到只使用当前账号，需要先手动切换账号。',
      SignAccountMode.savedPlatformSelection =>
        '一次扫码只使用账号页保存的当前平台签到账号，直接提交，不切换 IP。',
      SignAccountMode.perRunSelection => '每次在签到页选择账号，并逐个开关移动数据/换 IP 后提交。',
    };
  }

  static SignSubmitNetworkPolicy networkPolicyOf(SignAccountMode mode) {
    return switch (mode) {
      SignAccountMode.manualCurrent => SignSubmitNetworkPolicy.direct,
      SignAccountMode.savedPlatformSelection => SignSubmitNetworkPolicy.direct,
      SignAccountMode.perRunSelection => SignSubmitNetworkPolicy.reconnect,
    };
  }

  static Future<SignAccountMode> getMode(PlatformType platform) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_modeKey(platform));
    return SignAccountMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => SignAccountMode.manualCurrent,
    );
  }

  static Future<void> setMode(
    PlatformType platform,
    SignAccountMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey(platform), mode.name);
  }

  static Future<Set<String>> getSelectedAccountIds(
    PlatformType platform,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final validIds = AccountManager.getAccountsForPlatform(
      platform,
    ).map((user) => user.uid).toSet();
    final ids =
        (prefs.getStringList(_selectedKey(platform)) ?? const <String>[])
            .where(validIds.contains)
            .toSet();
    if (ids.length !=
        (prefs.getStringList(_selectedKey(platform)) ?? const <String>[])
            .length) {
      await prefs.setStringList(_selectedKey(platform), ids.toList());
    }
    return ids;
  }

  static Future<void> setSelectedAccountIds(
    PlatformType platform,
    Iterable<String> ids,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final validIds = AccountManager.getAccountsForPlatform(
      platform,
    ).map((user) => user.uid).toSet();
    final filtered =
        ids
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty && validIds.contains(id))
            .toSet()
            .toList()
          ..sort();
    await prefs.setStringList(_selectedKey(platform), filtered);
  }

  static Future<SignModeResolution> resolveUsers({
    required PlatformType platform,
    bool perRunUsesAllWhenNoSelection = true,
    List<User>? perRunSelection,
  }) async {
    final mode = await getMode(platform);
    final platformAccounts = AccountManager.getAccountsForPlatform(platform);
    final selectedIds = mode == SignAccountMode.savedPlatformSelection
        ? await getSelectedAccountIds(platform)
        : const <String>{};
    return resolveUsersFromState(
      platform: platform,
      mode: mode,
      platformAccounts: platformAccounts,
      currentSessionId: AccountManager.currentSessionId,
      savedSelectionIds: selectedIds,
      perRunSelection: perRunSelection,
      perRunUsesAllWhenNoSelection: perRunUsesAllWhenNoSelection,
    );
  }

  static SignModeResolution resolveUsersFromState({
    required PlatformType platform,
    required SignAccountMode mode,
    required List<User> platformAccounts,
    required String? currentSessionId,
    Set<String> savedSelectionIds = const <String>{},
    bool perRunUsesAllWhenNoSelection = true,
    List<User>? perRunSelection,
  }) {
    final platformIds = platformAccounts.map((user) => user.uid).toSet();
    final networkPolicy = networkPolicyOf(mode);

    if (mode == SignAccountMode.manualCurrent) {
      User? current;
      for (final user in platformAccounts) {
        if (user.uid == currentSessionId) {
          current = user;
          break;
        }
      }
      if (current == null) {
        return SignModeResolution(
          mode: mode,
          users: const <User>[],
          networkPolicy: networkPolicy,
          message: '请先在${platformLabel(platform)}账号页切换到要签到的当前账号',
        );
      }
      return SignModeResolution(
        mode: mode,
        users: <User>[current],
        networkPolicy: networkPolicy,
      );
    }

    if (mode == SignAccountMode.savedPlatformSelection) {
      final users = platformAccounts
          .where((user) => savedSelectionIds.contains(user.uid))
          .toList(growable: false);
      if (users.isEmpty) {
        return SignModeResolution(
          mode: mode,
          users: const <User>[],
          networkPolicy: networkPolicy,
          message: '暂无${platformLabel(platform)}签到账号，请到账号页勾选“当前平台下签到账号”后再签到',
        );
      }
      return SignModeResolution(
        mode: mode,
        users: users,
        networkPolicy: networkPolicy,
      );
    }

    final selected = perRunSelection
        ?.where((user) => platformIds.contains(user.uid))
        .toList(growable: false);
    final users = selected != null && selected.isNotEmpty
        ? selected
        : perRunUsesAllWhenNoSelection
        ? platformAccounts
        : const <User>[];
    return SignModeResolution(
      mode: mode,
      users: users,
      networkPolicy: networkPolicy,
    );
  }

  static Future<void> showEmptySelectionMessage(
    BuildContext context,
    PlatformType platform,
  ) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('暂无${platformLabel(platform)}签到账号，请到账号页勾选下方账号后保存'),
      ),
    );
  }

  static String _modeKey(PlatformType platform) {
    return '${_modePrefix}_${platformKey(platform)}';
  }

  static String _selectedKey(PlatformType platform) {
    return '${_selectedPrefix}_${platformKey(platform)}';
  }
}
