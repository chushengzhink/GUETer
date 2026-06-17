# GUETer

GUETer 是一个面向高校教学平台的 Flutter 课程助手，当前聚合学习通、雨课堂、畅课、课堂派、微助教等平台入口，提供课程管理、账号管理、签到、待办提醒、阅读、PDF 工具、云盘共享、局域网传输和虚拟局域网辅助功能。

本项目仅用于学习交流与技术研究，不是任何教学平台或学校的官方客户端。使用者应确保自己有权访问相关账号、课程和资源，并遵守学校及平台规则。

## 功能特性

### 多平台课程与账号

- 聚合学习通、雨课堂、畅课、课堂派、微助教等平台的课程入口与课程详情。
- 支持多账号本地保存、快速切换、登录状态检查和会话维护。
- 提供平台请求控制台，便于查看请求结果、错误日志和重试状态。
- 支持中英文界面、深色模式和多套 Material Design 3 主题风格。

### 签到与课堂活动

- 支持学习通、雨课堂、畅课、课堂派等平台的二维码、数字码、位置、雷达等签到能力，具体可用性取决于平台接口和账号权限。
- 支持课堂派多账号签到、共享签到房间、课程资料、公告、成员、话题、作业和考试入口。
- 支持畅课签到列表、数字签到、二维码签到、雷达签到、课程待办和仪表盘视图。
- 支持学习通课程章节、作业、测验、讨论、问卷、投票、评价和课堂活动入口。

### 待办、通知与工具

- 汇总跨平台待办事项，支持本地提醒和通知。
- 内置 PDF 阅读器，支持目录、页码跳转、夜间阅读和阅读进度保存。
- 提供 PDF 转图片、图片合并 PDF、压缩、页面提取、水印、打开和分享等文件工具。
- 提供本地复习中心，支持资料摘录转复习卡片、卡组管理、今日待复习和间隔重复。
- 提供资料全文搜索，索引本地下载、离线包、文件工具输出和复习卡片来源文件。
- Android 支持本地图片 OCR，可将扫描文字保存为 TXT、加入搜索索引或生成复习卡片。
- 提供学习时间轴，汇总待办、复习到期、签到记录和考试/作业截止，并支持导出本地日历文件。
- 提供资料状态面板，汇总下载目录、离线包、搜索索引、重复文件和本地缺失状态。
- 提供云盘共享入口，支持文件浏览、下载、上传、目录导航和按权限显示可用操作。
- 提供诊断修复中心，汇总请求日志、账号状态、网络状态、权限状态和可执行修复建议。
- 提供学术检索、电脑帮助文档、每日天文图等扩展工具入口。
- 支持声明式 Mod 插件，可扩展工具入口、快捷命令、文件预览动作、健康中心动作和模板化本地工作流。
- Android 支持今日概览桌面小组件，显示本地待办摘要、待复习数量和通知状态。

### 局域网与网络辅助

- 局域网传输模块支持附近设备发现、发送/接收文件、传输进度和设备名设置。
- 附近聊天室模块支持基于局域网/近场连接的临时会话。
- ZeroTier 模块提供虚拟局域网连接管理入口，便于在受支持平台上配置远程互联。

## 平台与权限

Android 版本会按功能申请相机、网络、定位、蓝牙、附近设备、通知、前台服务、文件读取等权限。权限用途如下：

- 相机：扫描课程、签到、登录或分享二维码。
- 网络：访问教学平台接口、更新检查、局域网传输和扩展工具。
- 定位、蓝牙、附近设备、Wi-Fi 状态：用于位置签到、雷达签到、附近设备发现和局域网传输。
- 文件读取与媒体访问：用于选择、读取、分享 PDF、图片和传输文件。
- 通知与精确闹钟：用于待办提醒和本地通知。

## 开发环境

```powershell
flutter --version
flutter pub get
flutter run
```

推荐环境：

- Flutter 3.35 或更高版本
- Dart 3.9 或更高版本
- JDK 17
- Android SDK 与 Gradle 环境

## Android 构建

公开仓库不保存签名证书、签名密码或第三方 API Key。Release 构建需要在本机准备被 Git 忽略的配置文件。

在 `android/local.properties` 中添加百度地图 Key：

```properties
BAIDU_MAP_API_KEY=your_baidu_map_api_key
```

在 `android/key.properties` 中配置本地签名：

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=app/your-release-key.jks
```

构建 Android arm64-v8a 安装包：

```powershell
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

正式发布建议开启 Dart 混淆并输出符号文件：

```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build\symbols
```

构建完成后，APK 位于：

- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

## 应用更新

应用支持从固定分享文件夹读取远端更新信息。公开仓库不内置真实分享地址、密码或私有部署信息，发布构建时应通过 `--dart-define` 注入更新源配置。

远端更新元数据使用 `update.txt` 承载 JSON，包含版本号、构建号、更新说明和 APK 下载页。强制更新由远端显式控制：只有当 `update.txt` 写入强制字段，或分享文件夹中存在类似 `force_目标版本_from_来源版本.txt` 的标记文件时，命中的旧版本才会进入强制更新弹窗。

强制更新弹窗不可通过返回键或点击外部关闭；未命中强制规则时仍保留普通“稍后 / 下载”更新提示。

## 测试与检查

```powershell
flutter analyze
flutter test
```

## 扩展与 Mod 插件

GUETer 支持本地声明式 Mod 插件。插件通过 UTF-8 JSON 清单声明入口、能力、权限和受控动作，不加载 Dart、Flutter、脚本、shell 或原生代码。

当前支持的扩展位置包括工具页入口、命令搜索、文件预览页动作和健康中心动作。插件可执行的能力限定在白名单内，例如打开链接、打开插件内 Markdown、复制文本、预览当前文件、分享当前文件、打开健康中心或打开内置查重清理页。

插件管理页内置模板库，可生成“复制文件路径”“资料转复习卡片”“打开诊断修复中心”“局域网发送当前文件”“保存文件备注”“HTTP GET 展示结果”等本地模板。模板生成后默认不启用，用户可先查看权限和入口再手动启用。

插件开发和使用说明见 [docs/plugin_development.md](docs/plugin_development.md)，示例插件见 [docs/examples/sample_plugin](docs/examples/sample_plugin)。

推送公开仓库前应额外检查：

```powershell
git status --short
git diff --cached
rg -n "api_key|secret|password|token|storePassword|keyAlias|Bearer|BAIDU_MAP_API_KEY" -S
```

命中账号字段、测试用例或接口变量名不一定是泄露，但真实账号、真实 token、签名密码、证书和 API Key 不应提交。

## 来源与致谢

本项目包含原仓库历史代码、当前仓库新增实现，以及对以下开源项目的参考、适配或改造。相关来源在 README 和 NOTICE 中保留，便于追溯。

- 学习通登录、课程与签到相关能力参考或改造自 [AneryCoft/course_helper](https://github.com/AneryCoft/course_helper)。
- 畅课相关能力参考或改造自 [wilinz/tronclass_plus](https://github.com/wilinz/tronclass_plus)。
- 课堂派课程、签到、作业、考试等模块参考或改造自 [roselle-luo/fuckketangpai_app](https://github.com/roselle-luo/fuckketangpai_app)。
- 学习通自动学习、任务流程、进度追踪等实现思路参考 [dsxksss/chaoxing_ft v0.1](https://github.com/dsxksss/chaoxing_ft/tree/v0.1)。
- 微助教相关接口流程参考 [zn-cn/wzj-sign-in-weixin](https://github.com/zn-cn/wzj-sign-in-weixin)。
- 局域网传输模块参考 [LocalSend](https://github.com/localsend/localsend) 和 [LocalSend Protocol](https://github.com/localsend/protocol)，相关 Apache-2.0 notice 见 `NOTICE`。
- Flutter 腾讯验证码插件依赖来自 [AneryCoft/flutter_tencent_captcha](https://github.com/AneryCoft/flutter_tencent_captcha)。

以上说明表示功能设计、接口流程、局部实现或协议存在参考与改造关系，并不表示逐文件完整复制。后续如继续引入外部代码，应在对应文件、README 或 NOTICE 中补充来源和许可证信息。

## 隐私与安全

- 本项目不提供云端账号同步，不主动上传用户账号、密码、cookie 或 token 到项目服务器。
- 账号、会话和本地记录仅保存在用户设备本地；请自行保护设备安全。
- 仓库不应包含个人账号、真实 cookie、真实 token、签名证书、签名密码、第三方 API Key、内网地址、私有服务端口或本地抓包数据。
- 云盘发布、审计和管理相关凭据仅应保存在私有部署环境中，客户端和公开仓库不保存管理员凭据。
- Mod 插件不执行任意代码，不能读取账号、Cookie、Token、OpenList 凭据、签到内部状态或私有服务配置。
- `key/`、`*.jks`、`key.properties`、`local.properties`、`.dart_appdata/`、抓取目录和参考工程目录均应保持忽略状态。

## 许可证

本仓库以 GPL-3.0 发布，详见 `LICENSE`。部分第三方来源或改造代码可能同时受其原许可证约束，相关说明见 `NOTICE` 及上方来源列表。
