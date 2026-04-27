# GUETer - 多平台课程助手

GUETer 是一个面向多教学平台的课程辅助应用，支持**学习通、雨课堂、畅课、课堂派**四大主流教学平台，为学生提供统一的课程管理、签到、待办汇总等功能。

项目仓库：https://github.com/chushengzhink/GUETer

## 核心功能

### 📚 多平台课程管理
- 支持学习通、雨课堂、畅课、课堂派四大平台
- 统一课程列表展示与管理
- 多账号保存与快速切换
- 登录态自动检查与维护
- 平台地址管理与健康检测

### ✅ 智能签到系统
- 多平台扫码签到（雨课堂/课堂派）
- 多账号批量签到支持
- 课堂派共享签到房间（单次扫码，多账号并行）
- 雨课堂课程详情与课堂入口串联
- 签到状态实时反馈

### 📋 待办汇总与通知
- 跨平台待办事项统一汇总
- 作业、考试、任务提醒
- 本地通知推送
- 精确定时提醒
- 待办完成状态追踪

### 🌤️ 天气查看
- 实时天气信息展示
- 基于百度地图定位
- 支持位置权限管理

### 🛠️ PDF 工具集
- PDF 转图片
- 图片合并为 PDF
- PDF 压缩优化
- PDF 页面提取
- 添加水印（防篡改）
- 自定义输出目录
- 文件直接打开/分享
- 最近任务记录

### 📖 阅读功能
- 内置 PDF 文档阅读器
- 目录/书签导航
- 全文搜索与页码跳转
- 夜间模式
- 阅读进度持久化

### 🔧 其他特性
- 请求控制台（查看请求结果、重试、错误日志）
- 畅课门户策略与重认证
- Material Design 3 设计语言
- 深色模式支持
- 多语言支持

## 代码来源与参考说明

本项目包含三类代码来源：

### A. 原项目继承代码
- 本仓库历史版本中原有模块与逻辑
- 包括基础页面结构、平台接入骨架、会话与网络基础设施

### B. 开源项目参考实现（按模块）
- 学习通登录 + 签到： https://github.com/AneryCoft/course_helper
- 畅课模块： https://github.com/wilinz/tronclass_plus
- 课堂派模块： https://github.com/roselle-luo/fuckketangpai_app
- 学习通自动学习核心逻辑（课程管理、任务执行、倍速、进度、任务追踪、会话管理）： https://github.com/dsxksss/chaoxing_ft/tree/v0.1
- 微助教： https://github.com/zn-cn/wzj-sign-in-weixin

说明：以上为“参考与借鉴来源”，并非逐文件完全拷贝；本项目已结合当前工程结构做了二次整合与改造。

## GPL v3 来源声明（补充）

为符合 GPL v3 及来源可追溯要求，现补充声明如下：

- 学习通登录 + 签到部分源码来源： https://github.com/AneryCoft/course_helper
- 畅课部分源码来源： https://github.com/wilinz/tronclass_plus
- 课堂派部分源码来源： https://github.com/roselle-luo/fuckketangpai_app
- 学习通以下能力的实现思路与接口流程来源： https://github.com/dsxksss/chaoxing_ft/tree/v0.1
	- 课程管理（自动获取课程列表）
	- 作业任务（视频、文档等学习任务）
	- 视频学习（1.0x / 2.0x）
	- 进度同步（任务进度展示）
	- 任务追踪（任务完成状态）
	- 会话管理（登录状态维护）

### C. 当前版本新增实现（本仓库）
- 工具分区（阅读 + PDF 工具）
- PDF 工具链与任务记录
- 请求控制台入口
- 设置页分组重构（外观主题前置）
- 更新检查地址切换到本仓库

## 开发与运行

### 环境
- Flutter: >= 3.35.x
- Dart: >= 3.9.x

### 安装依赖
```bash
flutter pub get
```

### 运行
```bash
flutter run
```

### 静态检查
```bash
flutter analyze
```

### Android Release 构建
```bash
flutter build apk --release --target-platform android-arm64
```

## 许可与免责声明

- License: GPL-3.0，详见 LICENSE
- 本项目仅用于学习交流，请遵守学校与平台相关规定
