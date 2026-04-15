# GUETer

GUETer 是一个面向多教学平台的课程辅助应用，当前覆盖学习通、雨课堂、畅课、课堂派，并预留微助教接入能力。

项目仓库（新）：https://github.com/chushengzhink/GUETer

## 主要功能

### 1. 课程与签到能力
- 多平台课程列表获取与展示
- 多账号批量扫码签到（雨课堂/课堂派）
- 课堂派共享签到房间（单次扫码，多账号并行签到）
- 雨课堂课程详情页与课堂入口串联

### 2. 账号与平台管理
- 多账号保存、切换、登录态检查
- 平台地址管理（恢复默认地址、健康检测）
- 畅课门户策略与重认证策略
- 请求控制台（查看请求结果、重试、错误日志）

### 3. 工具分区
底部导航第三栏为工具，包含两个子分区：
- 阅读
- PDF 工具

### 4. PDF 工具合集
- PDF 转图片
- 图片合并 PDF
- PDF 压缩
- PDF 提取页面
- 加水印（防篡改）

增强能力：
- 输出目录可自定义
- 输出文件可直接打开/分享
- 最近任务记录（时间、输入、输出、状态）

### 5. 阅读功能
- 内置 PDF 文档阅读
- 目录/书签导航
- 搜索、页码跳转
- 夜间模式、阅读设置
- 阅读进度持久化

## 代码来源与参考说明

本项目包含三类代码来源：

### A. 原项目继承代码
- 本仓库历史版本中原有模块与逻辑
- 包括基础页面结构、平台接入骨架、会话与网络基础设施

### B. 开源项目参考实现（按模块）
- 学习通 / 雨课堂： https://github.com/AneryCoft
- 畅课： https://github.com/wilinz/tronclass_plus
- 畅课登录美化接口参考： https://github.com/chongzi/guethub
- 课堂派： https://github.com/roselle-luo/fuckketangpai_app
- 微助教： https://github.com/zn-cn/wzj-sign-in-weixin

说明：以上为“参考与借鉴来源”，并非逐文件完全拷贝；本项目已结合当前工程结构做了二次整合与改造。

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
