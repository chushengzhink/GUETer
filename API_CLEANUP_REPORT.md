# 课堂派 API 清理报告

## 执行时间
2026年4月30日

## 清理原因
在完善课堂派功能时，发现存在重复的 API 实现：

### 重复的签到 API
1. **`ketangpai_sign_api.dart`** (新创建，154行)
   - 简单的 API 封装
   - 仅提供基础方法
   - **未被任何文件引用（0次使用）**

2. **`kt_sign.dart`** (现有，373行) + **`kt_follow_sign.dart`** (180行)
   - 完整的签到功能实现
   - 包含批量签到执行器
   - 包含签到记录存储
   - 包含 Token 健康检查
   - **正在被项目使用**

## 清理决策

### ❌ 删除文件
- `lib/api/ketangpai_sign_api.dart` (154行)

**删除原因**：
1. 功能重复且不完整
2. 未被任何文件引用
3. `kt_sign.dart` 提供了更完整的实现

### ✅ 保留文件
- `lib/api/kt_sign.dart` (373行)
- `lib/api/kt_follow_sign.dart` (180行)

**保留原因**：
1. 提供完整的签到功能
2. 包含批量签到执行器（`KtFollowSignExecutor`）
3. 正在被以下文件使用：
   - `lib/pages/ketangpai_private_sign_page.dart`
   - `lib/pages/ketangpai_shared_room_page.dart`

## 最终的课堂派 API 架构

### 签到相关 (2个文件)
- `lib/api/kt_sign.dart` - 签到 API 实现
- `lib/api/kt_follow_sign.dart` - 批量签到执行器

### 课程相关 (1个文件)
- `lib/api/ketangpai_course.dart` - 课程管理 API

### 考试相关 (1个文件)
- `lib/api/ketangpai_exam_api.dart` - 考试功能 API

### 考勤统计 (1个文件)
- `lib/api/ketangpai_attendance_api.dart` - 考勤统计 API

## 功能对比

### kt_sign.dart 提供的功能
```dart
class KTSignApi {
  // 扫码签到
  static Future<bool> scanToSign(String params, String token)
  
  // 数字签到
  static Future<bool> numberSign({
    required String code,
    required String token,
    required String signId,
  })
  
  // GPS签到
  static Future<bool> gpsSign({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
    String? courseId,
  })
  
  // 签入签出
  static Future<bool> checkInOutSign({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
  })
  
  // 获取数字签到码
  static Future<String?> getNumberCode({
    required String token,
    required String signId,
  })
  
  // 提取扫码参数
  static Map<String, String> extractScanParams(String rawUrl)
}
```

### kt_follow_sign.dart 提供的功能
```dart
class KtFollowSignExecutor {
  // 批量扫码签到
  static Future<KtFollowSignResult> signByScan({
    required String scanUrl,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
  })
  
  // 批量数字签到
  static Future<KtFollowSignResult> signByNumber({
    required String code,
    required String signId,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
  })
  
  // 批量GPS签到
  static Future<KtFollowSignResult> signByGps({
    required String signId,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
    String? latitude,
    String? longitude,
    String? accuracy,
    String? courseId,
  })
  
  // 批量签入签出
  static Future<KtFollowSignResult> signByCheckInOut({
    required String signId,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
    String? latitude,
    String? longitude,
    String? accuracy,
    String? courseId,
  })
}

class KtFollowSignResult {
  final int successCount;
  final int totalCount;
  final List<String> failedAccounts;
}
```

### 已删除的 ketangpai_sign_api.dart 功能
```dart
class KetangpaiSignApi {
  // 获取未完成签到列表
  static Future<Response> getNotFinishAttence(String courseId)
  
  // 获取数字签到码
  static Future<Response> getDigitAttence(String attenceId)
  
  // 执行签到
  static Future<Response> checkin({...})
  
  // 二维码签到
  static Future<Response> attenceResult({...})
  
  // 检查签到状态
  static bool isSignSuccess(Map<String, dynamic>? responseData)
  
  // 获取签到消息
  static String getSignMessage(Map<String, dynamic>? responseData, {bool success = false})
}
```

**对比结论**：
- `kt_sign.dart` 提供了更完整的实现（包含日志、错误处理、GPS坐标配置）
- `kt_follow_sign.dart` 提供了批量签到功能（多账号支持）
- 已删除的 `ketangpai_sign_api.dart` 功能较简单，且未被使用

## 清理效果

### 代码减少
- 删除 154 行未使用代码
- 避免了 API 重复和混淆

### 架构优化
- 保持单一职责原则
- 避免功能重复
- 清晰的 API 分层

### 维护性提升
- 减少了维护负担
- 避免了未来的混淆
- 统一了签到 API 入口

## 总结

成功清理了重复的签到 API，保留了功能更完整、正在使用的 `kt_sign.dart` 和 `kt_follow_sign.dart`。

**最终课堂派 API 文件数**：5个
- 签到：2个（kt_sign.dart, kt_follow_sign.dart）
- 课程：1个（ketangpai_course.dart）
- 考试：1个（ketangpai_exam_api.dart）
- 考勤：1个（ketangpai_attendance_api.dart）

所有 API 均有明确用途，无重复功能。
