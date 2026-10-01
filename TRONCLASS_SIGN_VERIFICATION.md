# 畅课签到功能稳定性验证报告

## 🔍 验证范围

验证以下核心功能点：
1. ✅ 畅课签到列表获取（`TronclassSignApi.getRollcalls()`）
2. ✅ 三种签到类型提交（二维码、数字、雷达）
3. ✅ Cookie/Session 隔离机制
4. ⚠️ **签到列表解析逻辑缺失**

---

## ✅ 已验证通过的功能

### 1. API 端点和请求方式 ✅

**签到列表获取**（`lib/api/tronclass_sign_api.dart:111-128`）：
```dart
static Future<Response> getRollcalls() async {
  final client = await TronclassClient.getInstance(userId);
  final url = '/api/radar/rollcalls?api_version=1.1.0';
  return await client.dio.get(url, options: Options(headers: headers));
}
```
- ✅ 端点正确：`/api/radar/rollcalls?api_version=1.1.0`
- ✅ 方法正确：`GET`
- ✅ 使用 `TronclassClient` 实现多用户隔离

**二维码签到**（`lib/api/tronclass_sign_api.dart:8-36`）：
```dart
static Future<Response> signQr({
  required String rollcallId,
  required String data,
  required String deviceId,
}) async {
  final url = '/api/rollcall/$rollcallId/answer_qr_rollcall';
  return await client.dio.put(url, data: body, options: Options(headers: headers));
}
```
- ✅ 端点正确：`/api/rollcall/{rollcallId}/answer_qr_rollcall`
- ✅ 方法正确：`PUT`
- ✅ 参数格式正确：`data`, `deviceId`

**数字签到**（`lib/api/tronclass_sign_api.dart:38-66`）：
```dart
static Future<Response> signNumber({
  required String rollcallId,
  required String numberCode,
  required String deviceId,
}) async {
  final url = '/api/rollcall/$rollcallId/answer_number_rollcall';
  return await client.dio.put(url, data: body, options: Options(headers: headers));
}
```
- ✅ 端点正确：`/api/rollcall/{rollcallId}/answer_number_rollcall`
- ✅ 方法正确：`PUT`
- ✅ 参数格式正确：`numberCode`, `deviceId`

**雷达签到**（`lib/api/tronclass_sign_api.dart:68-108`）：
```dart
static Future<Response> signRadar({
  required String rollcallId,
  required String deviceId,
  required double latitude,
  required double longitude,
  required double accuracy,
  // ... 其他可选参数
}) async {
  final url = '/api/rollcall/$rollcallId/answer?api_version=1.1.2';
  return await client.dio.put(url, data: body, options: Options(headers: headers));
}
```
- ✅ 端点正确：`/api/rollcall/{rollcallId}/answer?api_version=1.1.2`
- ✅ 方法正确：`PUT`
- ✅ 参数格式正确：经纬度、精度等

### 2. Cookie/Session 隔离机制 ✅

**TronclassClient 多用户实例管理**（`lib/api/tronclass_client.dart:54-94`）：
```dart
static final Map<String, TronclassClient> _instances = {};

static Future<TronclassClient> getInstance(String userId) async {
  if (_instances[userId] == null) {
    final instance = TronclassClient._();
    instance._userId = userId;
    instance._cookieJar = await _getCookieJar(userId); // 按用户隔离
    // ... 创建独立的 Dio 实例
    _instances[userId] = instance;
  }
  return _instances[userId]!;
}
```
- ✅ 每个用户有独立的 `TronclassClient` 实例
- ✅ 每个用户有独立的 `CookieJar`（路径：`cookies/tronclass/{userId}`）
- ✅ 每个用户有独立的 `Dio` 实例
- ✅ 自动注入 `x-session-id` 请求头（`_TronclassAuthInterceptor`）

### 3. 签到响应解析 ✅

**成功判断逻辑**（`lib/api/tronclass_sign_api.dart:131-143`）：
```dart
static bool isSignSuccess(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    final status = responseData['status']?.toString();
    return status == 'on_call' || status == 'on_call_fine';
  }
  return false;
}
```
- ✅ 与参考项目 `tronclass_plus` 一致
- ✅ 正确识别成功状态：`on_call` 或 `on_call_fine`

**消息提取逻辑**（`lib/api/tronclass_sign_api.dart:146-174`）：
```dart
static String getSignMessage(dynamic responseData) {
  if (responseData is Map<String, dynamic>) {
    // 优先返回 message 字段
    final message = responseData['message']?.toString() ??
                   responseData['msg']?.toString() ??
                   responseData['error']?.toString();
    
    if (message != null && message.isNotEmpty) {
      return message;
    }
    
    // 根据 status 返回默认消息
    final status = responseData['status']?.toString();
    if (status == 'on_call' || status == 'on_call_fine') {
      return '签到成功';
    } else if (status == 'late') {
      return '迟到签到成功';
    } else if (status == 'absent') {
      return '签到失败：缺勤';
    }
    
    return '签到完成';
  }
  return '签到完成';
}
```
- ✅ 优先使用服务器返回的消息
- ✅ 根据状态码提供友好的默认消息

### 4. UI 页面集成 ✅

**专用签到页面**：
- ✅ `TronclassQrSignPage`（二维码签到）- `lib/pages/tronclass_qr_sign_page.dart`
- ✅ `TronclassNumberSignPage`（数字签到）- `lib/pages/tronclass_number_sign_page.dart`
- ✅ `TronclassRadarSignPage`（雷达签到）- `lib/pages/tronclass_radar_sign_page.dart`

**签到流程**：
1. 用户选择签到会话
2. 跳转到对应的专用签到页面
3. 调用 `TronclassSignApi` 提交签到
4. 使用 `isSignSuccess()` 判断结果
5. 使用 `getSignMessage()` 显示消息

---

## ⚠️ 发现的问题

### 🔴 严重问题：签到列表解析逻辑缺失

**问题描述**：
`TCCourseApi.getSignActivities()` 已被标记为废弃并返回空列表，但 **没有实现新的签到列表解析逻辑**。

**影响范围**：
- `lib/pages/tronclass_sign_in.dart:99` - 签到页面无法获取签到列表
- `lib/pages/courses.dart:1918` - 课程页面无法显示签到活动

**当前代码**（`lib/api/course.dart:797-800`）：
```dart
static Future<List<Active>> getSignActivities(String courseId) async {
  // 已废弃：直接使用 TronclassSignApi.getRollcalls()
  return [];  // ❌ 直接返回空列表
}
```

**参考项目的正确实现**（`tronclass_plus-main/lib/data/service/tronclass.dart:129-134`）：
```dart
static Future<RollcallsResponse> getRollcalls(Dio dio) async {
  final url = "https://courses.guet.edu.cn/api/radar/rollcalls?api_version=1.1.0";
  final resp = await dio.get(url, options: Options(responseType: ResponseType.json));
  return RollcallsResponse.fromJson(resp.data);  // ✅ 解析为结构化对象
}
```

**响应数据结构**（`tronclass_plus-main/lib/data/model/tron_class/rollcalls_response/rollcalls_response.dart`）：
```json
{
  "rollcalls": [
    {
      "rollcall_id": 123456,
      "title": "第一次签到",
      "rollcall_status": "in_progress",
      "rollcall_time": "2026-04-30 10:00:00",
      "status": "on_call",
      "is_number": false,
      "is_radar": true,
      "is_expired": false,
      "course_id": 789,
      "course_title": "数据结构",
      "class_name": "计算机2班",
      "created_by_name": "张老师",
      // ... 其他字段
    }
  ]
}
```

**需要的字段映射**：
- `rollcall_id` → `Active.id`
- `title` → `Active.name`
- `rollcall_status` → `Active.extras['rollcall_status']`
- `status` → `Active.extras['status']`（用于判断是否已签到）
- `is_number` → 判断签到模式为 `number`
- `is_radar` → 判断签到模式为 `radar`
- 默认为 `qrcode` 模式（当 `is_number` 和 `is_radar` 都为 `false`）

---

## 🔧 需要修复的代码

### 修复 `TCCourseApi.getSignActivities()`

需要在 `lib/api/course.dart` 中实现完整的签到列表解析逻辑：

```dart
static Future<List<Active>> getSignActivities(String courseId) async {
  try {
    final response = await TronclassSignApi.getRollcalls();
    final data = response.data;
    
    if (data is! Map<String, dynamic>) {
      return [];
    }
    
    final rollcallsList = data['rollcalls'];
    if (rollcallsList is! List) {
      return [];
    }
    
    final activities = <Active>[];
    
    for (final rollcall in rollcallsList) {
      if (rollcall is! Map<String, dynamic>) continue;
      
      // 判断签到模式
      final isNumber = rollcall['is_number'] == true;
      final isRadar = rollcall['is_radar'] == true;
      String mode;
      if (isNumber) {
        mode = 'number';
      } else if (isRadar) {
        mode = 'radar';
      } else {
        mode = 'qrcode';
      }
      
      // 判断是否已签到
      final status = rollcall['status']?.toString() ?? '';
      final signed = status == 'on_call' || 
                     status == 'on_call_fine' || 
                     status == 'present';
      
      final active = Active(
        type: 2, // ActiveType.signIn
        id: rollcall['rollcall_id']?.toString() ?? '',
        name: rollcall['title']?.toString() ?? '签到',
        description: rollcall['course_title']?.toString() ?? '',
        startTime: 0,
        url: '',
        status: rollcall['rollcall_status'] == 'in_progress',
        extras: {
          '_mode': mode,
          '_signed': signed,
          'rollcall_status': rollcall['rollcall_status'],
          'rollcall_time': rollcall['rollcall_time'],
          'status': status,
          'class_name': rollcall['class_name'],
          'created_by_name': rollcall['created_by_name'],
          'updated_at': rollcall['rollcall_time'],
        },
      );
      
      activities.add(active);
    }
    
    return activities;
  } catch (e) {
    debugPrint('TCCourseApi.getSignActivities error: $e');
    return [];
  }
}
```

---

## 📋 验证清单

### ✅ 已验证通过
- [x] API 端点正确（`/api/radar/rollcalls`, `/api/rollcall/{id}/answer_*`）
- [x] HTTP 方法正确（GET 获取列表，PUT 提交签到）
- [x] 请求参数格式正确
- [x] Cookie/Session 多用户隔离机制
- [x] 签到响应解析逻辑（`isSignSuccess`, `getSignMessage`）
- [x] UI 页面集成（三个专用签到页面）

### ⚠️ 需要修复
- [ ] **签到列表解析逻辑**（`TCCourseApi.getSignActivities` 返回空列表）

---

## 🎯 修复优先级

### 🔴 P0 - 阻塞性问题（必须立即修复）
1. **实现 `TCCourseApi.getSignActivities()` 的签到列表解析逻辑**
   - 当前返回空列表，导致签到页面无法显示任何签到会话
   - 影响范围：所有畅课签到功能

### 🟡 P1 - 代码质量问题（建议修复）
1. 清理未使用的导入（`flutter analyze` 警告）
2. 移除不必要的空安全操作符（`?[]`）

---

## 📊 总体评估

| 功能模块 | 状态 | 说明 |
|---------|------|------|
| API 端点 | ✅ 正常 | 与参考项目一致 |
| 请求方式 | ✅ 正常 | GET/PUT 正确 |
| 参数格式 | ✅ 正常 | 符合服务器要求 |
| Cookie 隔离 | ✅ 正常 | 多用户独立实例 |
| 响应解析 | ✅ 正常 | 成功判断和消息提取正确 |
| **列表解析** | ❌ **缺失** | **返回空列表，功能不可用** |
| UI 集成 | ✅ 正常 | 三个专用签到页面 |

**结论**：
- ✅ 底层 API 实现完全正确
- ✅ Cookie 隔离机制正常工作
- ✅ 签到提交和响应解析正确
- ❌ **签到列表解析逻辑缺失，导致功能不可用**

**修复后即可正常使用畅课签到功能。**
