# 畅课签到 API 迁移分析报告

## 对比结果

### 参考项目 (tronclass_plus-main)
**架构：**
- 使用 `ChangkeClient` 单例管理 Dio 实例
- 使用 `TronClassService` 提供静态方法调用签到 API
- 直接传递 `ChangkeClient.instance.dio` 给 Service 方法

**签到 API 调用方式：**
```dart
// 数字签到
TronClassService.signNumber(
  ChangkeClient.instance.dio,
  rollcallId: rollcallId.toString(),
  numberCode: inputCode,
  deviceId: deviceId
)

// 雷达签到
TronClassService.signRadar(
  ChangkeClient.instance.dio,
  rollcallId: rollcallId.toString(),
  deviceId: deviceId,
  latitude: latitude,
  longitude: longitude,
  accuracy: accuracy,
)

// 二维码签到
TronClassService.signQr(
  ChangkeClient.instance.dio,
  rollcallId: rollcallId,
  data: data,
  deviceId: deviceId,
)
```

### 本项目 (course_helper-master)
**架构：**
- 使用 `TronclassClient` 按用户 ID 隔离实例
- 使用 `TronclassSignApi` 提供静态方法，内部自动获取用户实例
- 自动注入 `x-session-id` 和 User-Agent

**签到 API 调用方式：**
```dart
// 数字签到
TronclassSignApi.signNumber(
  rollcallId: widget.rollcallId,
  numberCode: code,
  deviceId: deviceId,
)

// 雷达签到
TronclassSignApi.signRadar(
  rollcallId: widget.rollcallId,
  deviceId: deviceId,
  latitude: latitude,
  longitude: longitude,
  accuracy: accuracy,
)

// 二维码签到
TronclassSignApi.signQr(
  rollcallId: widget.rollcallId,
  data: widget.data,
  deviceId: deviceId,
)
```

## 核心差异

### 1. 实例管理
- **参考项目**: 全局单例 `ChangkeClient.instance`
- **本项目**: 按用户 ID 隔离 `TronclassClient.getInstance(userId)`

### 2. API 调用
- **参考项目**: 需要手动传递 `dio` 实例
- **本项目**: API 内部自动获取当前用户的 Client 实例

### 3. 认证方式
- **参考项目**: 通过拦截器自动注入 `x-session-id`
- **本项目**: 同样通过拦截器自动注入，但支持多用户隔离

### 4. 响应判断
- **参考项目**: 直接检查 `status == "on_call"`
- **本项目**: 使用 `TronclassSignApi.isSignSuccess()` 统一判断

## 迁移状态

### ✅ 已完成迁移
1. **lib/api/tronclass_sign_api.dart** - 新 API 实现
   - `signQr()` - 二维码签到
   - `signNumber()` - 数字签到
   - `signRadar()` - 雷达签到
   - `isSignSuccess()` - 统一响应判断
   - `getSignMessage()` - 统一消息提取

2. **lib/pages/tronclass_number_sign_page.dart** - 已使用新 API
3. **lib/pages/tronclass_radar_sign_page.dart** - 已使用新 API
4. **lib/pages/tronclass_qr_sign_page.dart** - 已使用新 API

### ❌ 无旧 API 残留
通过 `grep` 搜索确认：
- ✅ 无 `TronClassService.` 调用
- ✅ 无 `ChangkeClient.instance.dio` 传递
- ✅ 无 `from 'package:tronclass/data/service/tronclass.dart'` 导入
- ✅ 无 `lib/data/service/` 目录

## 优势对比

### 本项目的改进
1. **多用户隔离**: 支持多账号同时登录，Cookie 和 Session 完全隔离
2. **更简洁的 API**: 无需手动传递 Dio 实例
3. **统一的响应处理**: `isSignSuccess()` 和 `getSignMessage()` 统一处理各种响应格式
4. **更好的错误处理**: 自动检测登录态失效（401/UNAUTHENTICATED）

### 参考项目的特点
1. **简单直接**: 全局单例，适合单用户场景
2. **显式依赖**: 手动传递 Dio，依赖关系更清晰

## 结论

**本项目已完全迁移到新的 API 架构，无需删除旧 API 文件（因为不存在）。**

新架构在保持参考项目核心逻辑的同时，增强了以下能力：
- 多用户隔离
- 更简洁的调用方式
- 统一的响应处理
- 更好的可维护性

所有签到功能（数字、雷达、二维码）均已使用新 API 实现，无旧代码残留。
