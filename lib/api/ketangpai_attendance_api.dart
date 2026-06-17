import 'platform_request_context.dart';
import 'platform_request_stability.dart';
import '../session/account.dart';
import '../platform.dart';

PlatformRequestOptions _ketangpaiAttendanceReadOptions(String operationId) {
  return PlatformRequestOptions(
    operationId: operationId,
    requestKind: PlatformRequestKind.read,
    allowControlledParallelism: true,
  );
}

/// 课堂派考勤统计 API
class KetangpaiAttendanceApi {
  /// 获取课程考勤统计
  /// 返回：出勤、旷课、迟到、早退、请假次数
  static Future<Map<String, int>> getAttendanceStats(String courseId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取考勤统计');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final url = '/AttenceApi/getAttenceStatistics';
      final body = {
        'courseid': courseId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiAttendanceReadOptions(
          'ketangpai.attendance.stats',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is Map<String, dynamic>) {
          return {
            'attendance': (data['attenceCount'] as num?)?.toInt() ?? 0,
            'absent': (data['absentCount'] as num?)?.toInt() ?? 0,
            'late': (data['lateCount'] as num?)?.toInt() ?? 0,
            'leaveEarly': (data['leaveEarlyCount'] as num?)?.toInt() ?? 0,
            'leave': (data['pleaseCount'] as num?)?.toInt() ?? 0,
          };
        }
      }

      return {
        'attendance': 0,
        'absent': 0,
        'late': 0,
        'leaveEarly': 0,
        'leave': 0,
      };
    } finally {
      context.dispose();
    }
  }

  /// 获取签到历史记录
  /// page: 页码（从1开始）
  /// limit: 每页数量
  static Future<List<Map<String, dynamic>>> getAttendanceHistory({
    required String courseId,
    int page = 1,
    int limit = 20,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取签到历史');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final url = '/AttenceApi/getAttenceList';
      final body = {
        'courseid': courseId,
        'page': page,
        'limit': limit,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiAttendanceReadOptions(
          'ketangpai.attendance.history',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      return [];
    } finally {
      context.dispose();
    }
  }

  /// 解析签到状态文本
  static String parseAttendanceStatus(String state) {
    switch (state) {
      case '1':
        return '出勤';
      case '2':
        return '迟到';
      case '3':
        return '早退';
      case '4':
        return '旷课';
      case '5':
        return '请假';
      default:
        return '未知';
    }
  }

  /// 获取签到状态颜色
  static int getAttendanceStatusColor(String state) {
    switch (state) {
      case '1':
        return 0xFF4CAF50; // 绿色 - 出勤
      case '2':
        return 0xFFFF9800; // 橙色 - 迟到
      case '3':
        return 0xFFFF5722; // 深橙色 - 早退
      case '4':
        return 0xFFF44336; // 红色 - 旷课
      case '5':
        return 0xFF2196F3; // 蓝色 - 请假
      default:
        return 0xFF9E9E9E; // 灰色 - 未知
    }
  }
}
