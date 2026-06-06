# GUETer 声明式 Mod 插件说明

GUETer Mod 使用 UTF-8 JSON 清单声明入口、能力和受控动作。应用不会加载 Dart、Flutter、脚本、shell 或原生代码，插件不能读取账号、Cookie、Token、OpenList 凭据、签到内部状态或私有服务配置。

插件目录位于应用支持目录：

```text
<application-support>/plugins/<plugin_id>/plugin.json
```

也可以在“插件管理”页面导入包含 `plugin.json` 的目录，或点击“生成示例”创建安全示例 Mod。

## Manifest 结构

字段名和协议值必须使用英文，显示文本可以使用中文。

```json
{
  "id": "dev.example.mod",
  "manifestVersion": 2,
  "name": {"zh": "示例 Mod", "en": "Example Mod"},
  "version": "1.0.0",
  "author": "GUETer",
  "description": {"zh": "演示受控能力", "en": "Demonstrates controlled capabilities"},
  "capabilities": ["toolEntry"],
  "allowedHosts": ["example.com"],
  "settingsSchema": [
    {
      "id": "prefix",
      "type": "text",
      "label": {"zh": "复制前缀", "en": "Copy prefix"},
      "defaultValue": "GUETer"
    }
  ],
  "permissions": ["clipboard", "localFileRead"],
  "entries": [
    {
      "id": "manual",
      "name": {"zh": "Mod 说明", "en": "Mod Manual"},
      "description": {"zh": "打开插件内 Markdown", "en": "Open bundled Markdown"},
      "icon": "markdown",
      "slots": ["tool", "command"],
      "action": {"type": "markdownPage", "path": "README.md"}
    }
  ]
}
```

## 能力与入口位置

`capabilities` 是插件级默认能力，兼容旧清单；entry 可以用 `slots` 单独指定显示位置并覆盖默认能力。

- `toolEntry` / `tool`：工具页入口。
- `quickCommand` / `command`：工具页搜索和快捷命令。
- `filePreviewAction` / `filePreview`：文件预览页动作。
- `healthAction` / `health`：健康中心相关入口。

entry 可选过滤字段：

- `fileExtensions`：文件预览动作适用扩展名，例如 `["pdf", ".txt", ".zip"]`。
- `platforms`：限制平台，例如 `["android", "windows"]`。
- `requiresPermissions`：入口额外需要的权限，必须已在插件级 `permissions` 声明。
- `contexts`：限制入口可接收的上下文，支持 `file`、`cloudFile`、`offlinePackage`、`text`、`healthIssue`。

`manifestVersion` 不写时按 v1 解析。v2 可声明 `settingsSchema` 和 `allowedHosts`。

## 权限

- `network`：允许发起受控 HTTP 请求。
- `openExternalUrl`：允许使用系统浏览器打开链接。
- `embeddedWebView`：允许打开内嵌 WebView。
- `clipboard`：允许写入剪贴板。
- `localFileRead`：允许读取插件目录内文件，或读取用户当前主动打开的文件上下文。
- `localFileWrite`：允许写入插件私有目录。

## 白名单动作

- `openUrl`：字段 `url`，需要 `openExternalUrl`。
- `webView`：字段 `url`，需要 `embeddedWebView`。
- `markdownPage`：字段 `path`，需要 `localFileRead`，只允许插件目录内 `.md` 文件。
- `httpRequest`：字段 `url`，需要 `network`；默认只允许 `GET`，`POST` 必须设置 `method: "POST"` 和 `allowPost: true`。
- `copyText`：字段 `text`，需要 `clipboard`。
- `route`：字段 `route`，只能跳转应用白名单路由。
- `previewFile`：字段 `path` 可选，需要 `localFileRead`；未填时使用当前文件预览上下文。
- `shareText`：字段 `text`，调用系统分享文本。
- `shareFile`：字段 `path` 可选，需要 `localFileRead`，只能分享当前文件或插件目录内文件。
- `openFolder`：字段 `path` 可选，需要 `localFileRead`，只能打开当前文件所在目录或插件目录内文件所在目录。
- `openHealthCenter`：打开请求与通知健康中心。
- `openDuplicateCleanup`：字段 `scope` 可选，只允许 `downloads`、`offlinePackages`、`fileTools` 三个内置本地目录范围。
- `sequence`：字段 `steps`，按顺序执行多个白名单动作，失败即停止。
- `showMessage`：字段 `text`，可选 `mode` 为 `snackbar` 或 `dialog`。
- `pickFile`：让用户主动选择一个文件，可用 `then` 指定后续动作。
- `saveTextFile`：字段 `text`，可选 `fileName`，只允许写入插件私有目录。
- `openBuiltinTool`：字段 `tool`，支持 `fileTools`、`localTransfer`、`cloud`、`health`。
- `sendToLocalTransfer`：把当前文件或用户选择文件交给局域网传输。
- `openWithFileTool`：字段 `toolAction`，支持 `preview`、`share`、`duplicateCleanup`。
- `copyJsonField`：字段 `json` 和 `field`，从 JSON 文本中复制指定字段。

## 模板变量

以下变量可用于动作字段中的字符串：

- `{filePath}`：当前文件本地路径。
- `{fileUri}`：当前文件 URI。
- `{fileName}`：当前文件名。
- `{fileExt}`：当前文件扩展名。
- `{fileSize}`：当前文件大小。
- `{text}`：当前文本上下文。
- `{appVersion}`：应用版本。
- `{platform}`：运行平台。
- `{setting.<id>}`：插件私有设置值。
- `{context.<key>}`：当前页面提供的低敏上下文字段。

模板变量不会提供账号、Cookie、Token、session、云盘凭据或签到状态。

## 安全规则

- URL 只允许 `http` 或 `https`。
- 如果 manifest 声明了 `allowedHosts`，网络动作只能访问这些 host。
- 本地文件动作只允许访问插件目录内文件，或用户当前主动打开的文件。
- 写文件只允许写入插件私有目录。
- 插件不能执行任意代码、动态 Dart、shell、原生命令或加载动态库。
- 插件不能修改应用账号、会话、签到、云盘凭据或私有服务配置。
- 无效插件会显示在“插件管理”的无效列表中，并展示解析错误。
- 插件发现后需要用户手动启用，入口才会出现在对应页面。

## 示例

完整示例见 [examples/sample_plugin](examples/sample_plugin)。示例包含：

- 工具页和命令搜索入口。
- 插件内 Markdown 说明页。
- 文件预览页复制当前文件路径。
- 健康中心入口。
