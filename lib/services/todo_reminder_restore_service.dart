import '../platform.dart';
import '../session/account.dart';
import 'notification_service.dart';
import 'platform_page_snapshot_store.dart';

/// Restore reminders independently of whether the lazy Todos page is opened.
class TodoReminderRestoreService {
  Future<void> restore() async {
    final notifications = NotificationService();
    await notifications.initialize();
    if (!await notifications.checkPermissionStatus()) return;
    final store = PlatformPageSnapshotStore();
    const names = {
      PlatformType.chaoxing: '学习通',
      PlatformType.tronclass: '畅课',
      PlatformType.rainClassroom: '雨课堂',
      PlatformType.ketangpai: '课堂派',
    };
    final allTodos = <Map<String, dynamic>>[];
    for (final entry in names.entries) {
      final owner = AccountManager.currentSessionForPlatform(entry.key);
      if (owner == null || owner.isEmpty) continue;
      final snapshot = await store.readList(
        platform: entry.key,
        userId: owner,
        page: 'todos',
      );
      if (snapshot == null ||
          AccountManager.currentSessionForPlatform(entry.key) != owner) {
        continue;
      }
      await notifications.scheduleNotificationsForTodos(
        snapshot.data,
        entry.value,
      );
      allTodos.addAll(
        snapshot.data.map((todo) => {...todo, 'platform_name': entry.value}),
      );
    }
    if (allTodos.isNotEmpty) {
      await notifications.updateOngoingNotification(allTodos);
    }
  }
}
