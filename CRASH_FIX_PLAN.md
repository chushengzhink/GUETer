# 崩溃问题修复计划

## 优先级分类

### 🔴 P0 - 会导致崩溃（立即修复）
1. **Missing mounted checks** (71 处)
   - 异步操作后调用 setState/SnackBar 前缺少 mounted 检查
   - 用户导航离开页面后调用会导致崩溃
   
2. **API 响应结构验证缺失**
   - 访问嵌套属性前未验证结构
   - 空指针异常导致崩溃

3. **后台任务未取消**
   - Timer 和轮询任务在页面销毁后继续运行
   - 导致内存泄漏和崩溃

### 🟡 P1 - 影响功能（后续修复）
4. **错误状态处理不完整**
   - 无法区分"无数据"和"加载失败"
   - 缺少重试机制

5. **用户反馈不足**
   - 批量操作无进度反馈
   - 错误信息不明确

---

## P0 修复详细计划

### 1. 修复 mounted 检查缺失

#### 影响文件（按优先级）：

**高频使用页面（优先）：**
1. `lib/pages/login.dart` - 登录页面
   - Line 18-26: QR 码登录回调
   - Line 34-37: 用户信息获取后
   - Line 119-162: QR 码轮询循环
   
2. `lib/pages/actives/sign_in/sign_in.dart` - 签到主页面
   - Line 469-491: 批量签到后
   - Line 537-544: 验证码验证后
   
3. `lib/pages/actives/sign_in/normal.dart` - 普通签到
   - Line 196-201: 图片上传后
   
4. `lib/pages/actives/sign_in/qrcode.dart` - 二维码签到
   - Line 296-300: 获取签到详情后

**修复模式：**
```dart
// 修复前
await someAsyncOperation();
setState(() { ... });

// 修复后
await someAsyncOperation();
if (!mounted) return;
setState(() { ... });
```

```dart
// 修复前
await someAsyncOperation();
ScaffoldMessenger.of(context).showSnackBar(...);

// 修复后
await someAsyncOperation();
if (!mounted) return;
if (context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(...);
}
```

---

### 2. 增强 API 响应验证

#### 影响文件：

1. `lib/pages/actives/sign_in/sign_in.dart`
   - Line 503-506: `result.contains('_')` 前验证 result 不为 null
   
2. `lib/pages/actives/sign_in/qrcode.dart`
   - Line 296-298: 验证 `signDetail` 结构
   
3. `lib/api/course.dart` (RainClassroom)
   - Line 266: 验证 `onLessonCourses['data']['onLessonClassrooms']` 存在
   - Line 316: 验证 `response.data['data']['value']` 存在

**修复模式：**
```dart
// 修复前
final value = response.data['data']['value'];

// 修复后
final data = response.data;
if (data == null || data['data'] == null) {
  throw Exception('Invalid response structure');
}
final value = data['data']['value'];
```

---

### 3. 修复后台任务泄漏

#### 影响文件：

1. `lib/pages/login.dart`
   - Line 36: `_pollTimer` 需要在 dispose 中取消
   - Line 119-162: 轮询循环需要可中断
   
2. `lib/pages/courses.dart`
   - Line 341-346: 定期刷新 Timer 需要在 dispose 中取消

**修复模式：**
```dart
class _MyPageState extends State<MyPage> {
  Timer? _timer;
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

---

## 修复顺序

### 第一批（最关键）：
1. ✅ `lib/pages/login.dart` - 登录页面 mounted 检查
2. ✅ `lib/pages/actives/sign_in/sign_in.dart` - 签到主页面 mounted 检查
3. ✅ `lib/pages/login.dart` - 后台任务取消

### 第二批：
4. ✅ `lib/pages/actives/sign_in/*.dart` - 各签到策略页面 mounted 检查
5. ✅ `lib/api/course.dart` - API 响应验证
6. ✅ `lib/pages/courses.dart` - 课程列表页面修复

### 第三批：
7. ✅ 其他页面的 mounted 检查
8. ✅ 全局 API 响应验证增强

---

## 测试验证

修复后需要测试的场景：

1. **导航测试**
   - 登录过程中返回
   - 签到过程中返回
   - 批量操作中返回

2. **网络异常测试**
   - API 返回 null
   - API 返回格式错误
   - 网络超时

3. **后台任务测试**
   - 页面销毁后 Timer 是否停止
   - 内存泄漏检测

---

## 预期结果

修复后应达到：
- ✅ 无 mounted 相关崩溃
- ✅ 无空指针异常崩溃
- ✅ 无内存泄漏
- ✅ 用户可以安全地在任何时候返回/导航

---

**生成时间**: 2026-04-30  
**预计修复时间**: 2-3 小时  
**影响文件数**: ~15 个核心文件
