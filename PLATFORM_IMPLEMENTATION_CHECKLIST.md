# 多平台课程助手 - 核心功能实现对比清单

## 项目概述
本文档对比当前项目与参考项目的核心功能实现完整性。

**参考项目：**
- 畅课（Tronclass）：`tronclass_plus-main`
- 雨课堂（RainClassroom）：`yuketang`
- 学习通（Chaoxing）：`yuketang`
- 课堂派（Ketangpai）：`ktpwarp-server-master` + `fuckketangpai_app-main`

---

## 1. 畅课（Tronclass）

### 参考实现
- **文件**：`tronclass_plus-main/lib/data/service/tronclass.dart`
- **基础 URL**：`https://courses.guet.edu.cn/api/`

### 当前实现
- **登录**：`lib/api/login.dart` (TCLoginApi)
- **签到**：`lib/api/tronclass_sign_api.dart` ✅
- **客户端管理**：`lib/api/tronclass_client.dart` ✅

### 功能对比

| 功能模块 | 参考实现 | 当前实现 | 状态 |
|---------|---------|---------|------|
| **登录流程** | | | |
| OAuth2 授权码获取 | `getLoginCode()` | `TCLoginApi.getLoginCode()` | ✅ 完整 |
| 访问令牌获取 | `getAccessToken()` | `TCLoginApi.getAccessToken()` | ✅ 完整 |
| 会话 ID 获取 | `loginDesktopEndpoint()` | `TronclassClient.login()` | ✅ 完整 |
| **签到功能** | | | |
| 二维码签到 | `signQr(rollcallId, data, deviceId)` | `TronclassSignApi.signQr()` | ✅ 完整 |
| 数字签到 | `signNumber(rollcallId, numberCode, deviceId)` | `TronclassSignApi.signNumber()` | ✅ 完整 |
| 雷达/GPS 签到 | `signRadar(rollcallId, latitude, longitude, ...)` | `TronclassSignApi.signRadar()` | ✅ 完整 |
| 获取签到列表 | `getRollcalls()` | `TronclassSignApi.getRollcalls()` | ✅ 完整 |
| **会话管理** | | | |
| x-session-id 管理 | 手动管理 | `TronclassAuthManager` 自动管理 | ✅ 完整 |
| 多用户隔离 | 无 | `TronclassClient` 实例隔离 | ✅ 增强 |

### API 端点对比

| 端点 | 参考实现 | 当前实现 | 匹配 |
|-----|---------|---------|------|
| 二维码签到 | `PUT /api/rollcall/{id}/answer_qr_rollcall` | 相同 | ✅ |
| 数字签到 | `PUT /api/rollcall/{id}/answer_number_rollcall` | 相同 | ✅ |
| 雷达签到 | `PUT /api/rollcall/{id}/answer?api_version=1.1.2` | 相同 | ✅ |
| 签到列表 | `GET /api/radar/rollcalls?api_version=1.1.0` | 相同 | ✅ |

### 实现质量评估
- ✅ **完整性**：所有核心签到功能已实现
- ✅ **架构优势**：使用 `TronclassClient` 实现多用户隔离，优于参考实现
- ✅ **会话管理**：`TronclassAuthManager` 自动持久化 session_id
- ✅ **请求拦截**：自动注入 `x-session-id` 头部

**结论**：✅ **畅课功能完整实现，且架构优于参考项目**

---

## 2. 雨课堂（RainClassroom）

### 参考实现
- **文件**：`yuketang/lib/api/course.dart` (RCCourseApi)
- **基础 URL**：`https://www.yuketang.cn/`

### 当前实现
- **登录**：`lib/api/login.dart` (RCLoginApi)
- **签到**：`lib/api/rainclassroom_sign_api.dart` ✅
- **课程**：`lib/api/rainclassroom_course_api.dart` ✅
- **考试**：`lib/api/rainclassroom_exam.dart` ✅

### 功能对比

| 功能模块 | 参考实现 | 当前实现 | 状态 |
|---------|---------|---------|------|
| **登录功能** | | | |
| 二维码登录 | `RCLoginApi` | `RCLoginApi.qrLogin()` | ✅ 完整 |
| 轮询登录状态 | 支持 | 支持 | ✅ 完整 |
| **签到功能** | | | |
| 扫描二维码 | `scan(qrCodeUrl)` | `RainClassroomSignApi.scan()` | ✅ 完整 |
| 签到进班 | `checkIn(lessonId)` | `RainClassroomSignApi.checkIn()` | ✅ 完整 |
| Token 管理 | `_setToken()` | `_setToken()` | ✅ 完整 |
| **课堂功能** | | | |
| 获取 PPT | `getPresentation(presentationId)` | `RainClassroomSignApi.getPresentation()` | ✅ 完整 |
| 提交答案 | `answer(problemId, problemType, ...)` | `RainClassroomSignApi.submitAnswer()` | ✅ 完整 |
| 延时提交 | 支持 | 支持 | ✅ 完整 |
| **课程管理** | | | |
| 获取课程列表 | `getCourses()` | `RainClassroomCourseApi.getCourses()` | ✅ 完整 |
| 获取进行中课程 | `getOnLessonAndUpcomingExam()` | 支持 | ✅ 完整 |
| **考试功能** | | | |
| 获取考试列表 | 支持 | `RainClassroomExamApi.getExamList()` | ✅ 完整 |
| 获取考试 Token | 支持 | `RainClassroomExamApi.getExamToken()` | ✅ 完整 |
| 获取试题 | 支持 | `RainClassroomExamApi.getExamProblems()` | ✅ 完整 |
| 提交答案 | 支持 | `RainClassroomExamApi.submitAnswers()` | ✅ 完整 |

### API 端点对比

| 端点 | 参考实现 | 当前实现 | 匹配 |
|-----|---------|---------|------|
| 扫描二维码 | `POST /api/v3/app/scan` | 相同 | ✅ |
| 签到进班 | `POST /api/v3/lesson/checkin` | 相同 | ✅ |
| 获取 PPT | `GET /api/v3/lesson/presentation/fetch` | 相同 | ✅ |
| 提交答案 | `POST /api/v3/lesson/problem/answer` | 相同 | ✅ |
| 重试答案 | `POST /api/v3/lesson/problem/retry` | 相同 | ✅ |

### 实现质量评估
- ✅ **完整性**：所有核心功能已实现
- ✅ **签到流程**：二维码扫描 → 签到进班 → Token 管理
- ✅ **答题功能**：支持 6 种题型（单选/多选/投票/填空/主观/判断）
- ✅ **考试模块**：完整的考试流程（获取列表 → 获取 Token → 获取试题 → 提交答案）

**结论**：✅ **雨课堂功能完整实现**

---

## 3. 学习通（Chaoxing）

### 参考实现
- **文件**：`yuketang/lib/api/course.dart` (CXCourseApi)
- **基础 URL**：`https://mobilelearn.chaoxing.com/`

### 当前实现
- **登录**：`lib/api/login.dart` (CXLoginApi)
- **签到**：`lib/api/chaoxing_sign_api.dart` ✅
- **课程**：`lib/api/chaoxing_course_api.dart` ✅
- **测验**：`lib/api/chaoxing_quiz_api.dart` ✅
- **作业**：`lib/api/chaoxing_homework_api.dart` ✅

### 功能对比

| 功能模块 | 参考实现 | 当前实现 | 状态 |
|---------|---------|---------|------|
| **登录功能** | | | |
| 账号密码登录 | 支持 | `CXLoginApi.login()` | ✅ 完整 |
| **签到功能（5 种类型）** | | | |
| 普通签到 | 支持 | `ChaoxingSignApi.signNormal()` | ✅ 完整 |
| 二维码签到 | 支持 | `ChaoxingSignApi.signQrcode()` | ✅ 完整 |
| 位置签到 | 支持 | `ChaoxingSignApi.signLocation()` | ✅ 完整 |
| 手势签到 | 支持 | `ChaoxingSignApi.signCode()` | ✅ 完整 |
| 签到码签到 | 支持 | `ChaoxingSignApi.signCode()` | ✅ 完整 |
| **高级签到功能** | | | |
| 验证码支持 | 支持 | 支持（validate 参数） | ✅ 完整 |
| 人脸识别 | 支持 | `ChaoxingSignApi.getFaceId()` | ✅ 完整 |
| 签到码验证 | 支持 | `ChaoxingSignApi.checkSignCode()` | ✅ 完整 |
| 签到详情 | 支持 | `ChaoxingSignApi.getSignDetail()` | ✅ 完整 |
| 群聊签到 | 支持 | `ChaoxingSignApi.groupSign()` | ✅ 完整 |
| **课程管理** | | | |
| 获取课程列表 | `getCourses()` | `ChaoxingCourseApi.getCourses()` | ✅ 完整 |
| 获取活动列表 | `getActiveList()` | `ChaoxingCourseApi.getActiveList()` | ✅ 完整 |
| 活动类型识别 | 支持 | 支持（ActiveType 枚举） | ✅ 完整 |
| **作业/考试** | | | |
| 获取作业列表 | 支持 | `ChaoxingHomeworkApi.getWorkList()` | ✅ 完整 |
| 获取考试列表 | 支持 | `ChaoxingQuizApi.getExamList()` | ✅ 完整 |

### API 端点对比

| 端点 | 参考实现 | 当前实现 | 匹配 |
|-----|---------|---------|------|
| 签到接口 | `GET /pptSign/stuSignajax` | 相同 | ✅ |
| 活动列表 | `GET /ppt/activeAPI/taskactivelist` | 相同 | ✅ |
| 签到详情 | `GET /newsign/signDetail` | 相同 | ✅ |
| 验证签到码 | `GET /widget/sign/pcStuSignController/checkSignCode` | 相同 | ✅ |
| 人脸 ID | `GET https://passport2-api.chaoxing.com/api/getUserFaceid` | 相同 | ✅ |

### 实现质量评估
- ✅ **完整性**：所有核心功能已实现
- ✅ **签到类型**：支持全部 5 种签到类型
- ✅ **高级功能**：验证码、人脸识别、签到码验证
- ✅ **加密支持**：使用 `EncryptionUtil` 处理设备指纹和参数加密

**结论**：✅ **学习通功能完整实现，且功能最全面**

---

## 4. 课堂派（Ketangpai）

### 参考实现
- **文件**：
  - `ktpwarp-server-master/签到.ts`
  - `fuckketangpai_app-main/lib/Internet/network.dart`
- **基础 URL**：`https://openapiv5.ketangpai.com/`

### 当前实现
- **登录**：`lib/api/login.dart` (KTLoginApi)
- **签到**：`lib/api/ketangpai_sign_api.dart` ✅
- **签到执行**：`lib/api/kt_sign.dart` ✅
- **跟随签到**：`lib/api/kt_follow_sign.dart` ✅
- **课程**：`lib/api/ketangpai_course.dart` ✅

### 功能对比

| 功能模块 | 参考实现 | 当前实现 | 状态 |
|---------|---------|---------|------|
| **登录功能** | | | |
| 账号密码登录 | 支持 | `KTLoginApi.login()` | ✅ 完整 |
| Token 管理 | 支持 | `AccountManager` 管理 | ✅ 完整 |
| **签到功能（4 种类型）** | | | |
| 数字签到 | `process数字签到()` | `KetangpaiSignApi.checkin(code=...)` | ✅ 完整 |
| GPS 签到 | `processGps签到()` | `KetangpaiSignApi.checkin(latitude=...)` | ✅ 完整 |
| 签入签出签到 | `process签入签出签到()` | `KetangpaiSignApi.checkin()` | ✅ 完整 |
| 二维码签到 | `processQrcode签到()` | `KetangpaiSignApi.attenceResult()` | ✅ 完整 |
| **签到辅助** | | | |
| 获取数字签到码 | `getDigitAttence` | `KetangpaiSignApi.getDigitAttence()` | ✅ 完整 |
| 获取未完成签到 | `getNotFinishAttenceStudent` | `KetangpaiSignApi.getNotFinishAttence()` | ✅ 完整 |
| **课程管理** | | | |
| 获取课程列表 | `/CourseApi/semesterCourseList` | `KetangpaiCourseApi.getCoursesList()` | ✅ 完整 |
| 获取课程内容 | `/FutureV2/CourseMeans/getCourseContent` | `KetangpaiCourseApi.getCourseContent()` | ✅ 完整 |
| 获取签到中课程 | `checkIncomplete签到()` | `KetangpaiCourseApi.getSigningCourses()` | ✅ 完整 |
| **高级功能** | | | |
| 跟随签到执行器 | 无 | `KTFollowSignExecutor` | ✅ 增强 |
| 多账号签到 | 无 | 支持 | ✅ 增强 |

### API 端点对比

| 端点 | 参考实现 | 当前实现 | 匹配 |
|-----|---------|---------|------|
| 签到接口 | `POST /AttenceApi/checkin` | 相同 | ✅ |
| 二维码签到 | `POST /AttenceApi/AttenceResult` | 相同 | ✅ |
| 获取签到码 | `POST /AttenceApi/getDigitAttence` | 相同 | ✅ |
| 未完成签到 | `POST /AttenceApi/getNotFinishAttenceStudent` | 相同 | ✅ |
| 课程列表 | `POST /CourseApi/semesterCourseList` | 相同 | ✅ |

### 实现质量评估
- ✅ **完整性**：所有核心功能已实现
- ✅ **签到类型**：支持全部 4 种签到类型
- ✅ **架构优势**：`KTFollowSignExecutor` 支持多账号跟随签到
- ✅ **请求管理**：使用 `PlatformRequestContext` 统一管理

**结论**：✅ **课堂派功能完整实现，且架构优于参考项目**

---

## 总体评估

### 功能完整性总结

| 平台 | 登录 | 签到 | 课程列表 | 考试/作业 | 整体状态 | 备注 |
|-----|------|------|---------|----------|---------|------|
| **畅课** | ✅ | ✅ (3 种) | ✅ | ⚠️ 通用 | ✅ **完整** | 架构优于参考 |
| **雨课堂** | ✅ | ✅ (二维码) | ✅ | ✅ | ✅ **完整** | 考试模块完整 |
| **学习通** | ✅ | ✅ (5 种) | ✅ | ✅ | ✅ **完整** | 功能最全面 |
| **课堂派** | ✅ | ✅ (4 种) | ✅ | ⚠️ 通用 | ✅ **完整** | 架构优于参考 |

### 架构优势

当前项目相比参考项目的架构改进：

1. **多用户隔离**
   - ✅ 每个平台每个用户独立的 Dio 实例
   - ✅ 独立的 Cookie 存储路径：`cookies/{platform}/{userId}`
   - ✅ 自动会话管理（Tronclass x-session-id、Ketangpai token）

2. **统一请求管理**
   - ✅ `PlatformRequestContext` 统一请求接口
   - ✅ 自动重定向处理
   - ✅ 自动 JSON 解析

3. **拦截器机制**
   - ✅ 自动注入平台特定认证头部
   - ✅ 自动检测认证过期（401/UNAUTHENTICATED）
   - ✅ 自动重试机制（指数退避）

4. **会话持久化**
   - ✅ `TronclassAuthManager` 持久化 session_id
   - ✅ `AccountManager` 统一管理账号信息
   - ✅ 登录前自动清理旧会话

### 已知限制

1. **考试/作业模块**
   - 畅课：使用通用 `course.dart`，未实现专用考试 API
   - 课堂派：使用通用 `course.dart`，未实现专用考试 API
   - 影响：功能可用但不够精细化

2. **UI 集成**
   - 所有 API 已实现，但部分平台的 UI 页面可能需要完善
   - 建议：检查 `lib/pages/` 下各平台的页面实现

---

## 结论

### ✅ 核心功能完整性：100%

所有四个平台的核心签到功能均已完整实现，且 API 端点与参考项目完全匹配。

### ✅ 架构质量：优于参考项目

- 多用户隔离机制完善
- 统一的请求管理接口
- 自动化的会话管理
- 完善的错误处理和重试机制

### 建议后续优化

1. **畅课考试模块**：参考 `tronclass_plus-main` 实现专用考试 API
2. **课堂派考试模块**：参考 `fuckketangpai_app-main` 实现专用考试 API
3. **UI 完善**：检查并完善各平台的 UI 页面
4. **测试覆盖**：为核心签到流程添加集成测试

---

**生成时间**：2026-04-30  
**对比版本**：v1.0.2
