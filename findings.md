# 重构发现

- 起点 main，13 个已修改文件与 8 个未跟踪报告；包含考试页、账号更新面板等用户改动，已保存原始 diff。
- main.dart 使用索引维护导航且 IndexedStack 首次创建全部页面；动态调用课程可见性。
- FloatingNavBar 等待动画后才切换，快速点击可产生延迟回调。
- 工具页超过 6000 行，有独立青绿配色、转盘和搜索弹层；全部工具动作应保持稳定 ID。
- 已有 AppAsyncState、AppAsyncView、设计 tokens、布局偏好和性能设置，可增量复用。
- 一些测试断言源码字符串；受重构影响的布局测试需要换成行为测试。
- 基线依赖缓存缺失，flutter pub get 恢复后分析正常。2 个原测试失败分别是登录乱码与课堂派凭据刷新未调用服务器验证，已修复，完整539测试通过。
- 待办原实现取平台首个账号且没有绑定账号事件，已改为读取平台选中账号并隔离在途数据。
- 考试旧答案保存响应可能覆盖较新输入，且多请求共享单一 saving 布尔值；已串行同题写入并正确计数、保留未保存集合。
- Android 当前无可用 adb 设备。界面截图来自 Flutter widget 渲染，外部服务初始化关闭，记录中明确区别于真机截图。

## 2026-09-07 Beta investigation
- Tronclass get<Map<String,dynamic>> casts text responses before validation.
- KTP list queries swallow errors; data.lists pending attendance omitted.
- Actual beta entry is CourseWorkspace and AccountContextHeader, not legacy showcase builders.
- Baseline: analyzer clean; 572 tests passed during planning. No live responses supplied.
- Final caller review found two legacy KTP pages without propagated-error handling and a pending-attendance facade still swallowing errors; fixed and covered by regression tests.
- Cached semester changes previously skipped refresh; now explicitly refresh. A full CoursesPage/Dio replay verifies request sharing, retained cache/timestamp, and stale semester rejection.
- Local origin/master 3342a7b uses a different Tronclass read path with JSON decoding and null KTP semester defaults; it still hides read failures. Detailed static comparison is in docs/beta-platform-fixes.md.
