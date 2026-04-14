# GUETer

GUETer 是一个面向多教学平台的课程辅助应用，目前支持学习通、雨课堂、畅课、课堂派（以及微助教能力接入）。

## 平台能力

- 多账号管理与账号切换
- 课程列表与活动入口
- 平台签到相关能力（按平台差异化支持）
- 畅课门户打开策略、重认证策略
- 一键健康检查、诊断包、常见问题修复

## 各平台参考源码来源

为尊重开源社区，本项目在相关页面和许可说明中保留了参考来源：

- 学习通 / 雨课堂参考：<https://github.com/AneryCoft>
- 畅课参考：<https://github.com/wilinz/tronclass_plus>
- 畅课登录美化接口参考：<https://github.com/chongzi/guethub>
- 课堂派参考：<https://github.com/roselle-luo/fuckketangpai_app>
- 微助教参考：<https://github.com/zn-cn/wzj-sign-in-weixin>

## 本地使用方法

### 1. 环境准备

- Flutter SDK: `>=3.35.x`
- Dart SDK: `>=3.9.x`
- Windows 构建请安装 Visual Studio C++ 桌面开发组件

### 2. 拉取与安装依赖

```bash
flutter pub get
```

### 3. 运行（开发模式）

```bash
flutter run
```

指定平台示例：

```bash
flutter run -d windows
```

### 4. 构建发布包（64 位）

Windows 64 位发布：

```bash
flutter build windows --release
```

产物目录：

- `build/windows/x64/runner/Release/`

## GitHub 轻量发布建议（只发源码）

仓库体积通常被以下目录拉大：

- `build/`
- `.dart_tool/`
- 本地缓存目录

本项目已在 `.gitignore` 中忽略大部分构建与缓存目录。发布到 GitHub 时，建议只提交源码与必要配置文件（`lib/`, `android/`, `ios/`, `windows/`, `pubspec.yaml`, `README.md` 等）。

## 安全与签名说明

- Windows 安装包“自动签名”需要有效代码签名证书（通常为组织证书）。
- 无证书时只能生成未签名二进制，可能触发 SmartScreen 或杀毒软件误报。
- 若需降低误报，请使用正式代码签名证书对发布包签名后再分发。

## 许可证

本项目采用 **GNU General Public License v3.0 (GPL-3.0)**。

- 许可证全文见 [LICENSE](LICENSE)
- 分发二进制时需同时遵守 GPL-3.0 对对应源代码与版权声明的要求

## 免责声明

本项目仅用于学习与技术研究，请在遵守学校与平台相关规定的前提下使用。
