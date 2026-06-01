// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appCourses => '课程';

  @override
  String get appAccounts => '账号';

  @override
  String get appTodos => '待办';

  @override
  String get appTools => '工具';

  @override
  String get appSettings => '设置';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String latestVersionLabel(String version) {
    return '最新版本: v$version';
  }

  @override
  String get updateNotesLabel => '更新内容:';

  @override
  String get laterButton => '稍后';

  @override
  String get downloadButton => '前往下载';

  @override
  String get anonymousChatTitle => '💬 匿名聊天';

  @override
  String get anonymousChatSubtitle => '基于 Nearby Connections 的附近设备匿名聊天与文件分享';

  @override
  String get localTransferTitle => '局域网快传';

  @override
  String get localTransferSubtitle => '兼容 LocalSend，局域网内自动发现并传输文件/文本';

  @override
  String get readingTitle => '阅读';

  @override
  String get readingSubtitle => '阅读功能已并入工具分区';

  @override
  String get academicSearchTitle => '📎 论文检索';

  @override
  String get academicSearchSubtitle =>
      '并行检索 CrossRef 与 arXiv，支持 BibTeX 与 PDF 导出';

  @override
  String get apodCardTitle => '今日星空';

  @override
  String get apodLoadingSubtitle => '正在加载 NASA 今日天文图片...';

  @override
  String get apodErrorSubtitle => '无法加载今日天文图片';

  @override
  String get apodUnavailableSubtitle => 'NASA 今日 APOD 不是图片，点击查看详情。';

  @override
  String get apodRefreshTooltip => '刷新天文图片';

  @override
  String get apodDetailTitle => '今日星空';

  @override
  String get apodDateLabel => '日期';

  @override
  String get apodAboutLabel => '简介';

  @override
  String get apodNonImageNotice => 'NASA 今日 APOD 不是图片，原始内容可能是视频或其他媒体类型。';

  @override
  String get toolsPageTitle => '工具';

  @override
  String get toolsTabReading => '阅读';

  @override
  String get toolsTabPdf => 'PDF';

  @override
  String get toolsTabGueter => 'GUETer';

  @override
  String get pickPdfOutputDirectory => '选择 PDF 工具输出目录';

  @override
  String get statusSelectTool => '请选择一个工具开始';

  @override
  String statusOutputDirChanged(String path) {
    return '输出目录已切换为: $path';
  }

  @override
  String get statusOutputDirReset => '输出目录已恢复为默认临时目录';

  @override
  String toolRunFailed(String error) {
    return '执行失败: $error';
  }

  @override
  String openFailedMessage(String message) {
    return '打开失败: $message';
  }

  @override
  String get pdfOutputShareText => 'PDF 工具输出文件';

  @override
  String get pdfToImagesTitle => 'PDF 转图片';

  @override
  String get pdfToImagesSubtitle => '导出为 PNG';

  @override
  String get imagesToPdfTitle => '图片合并 PDF';

  @override
  String get imagesToPdfSubtitle => '多图合一';

  @override
  String get compressPdfTitle => 'PDF 压缩';

  @override
  String get compressPdfSubtitle => '减小体积';

  @override
  String get extractPagesTitle => '提取页面';

  @override
  String get extractPagesSubtitle => '按页码提取';

  @override
  String get watermarkTitle => '加水印';

  @override
  String get watermarkSubtitle => '防篡改保护';

  @override
  String get extractPagesDialogTitle => '输入提取页码';

  @override
  String extractPagesHint(int count) {
    return '示例: 1,3,5-8 (总页数 $count)';
  }

  @override
  String get cancelButton => '取消';

  @override
  String get confirmButton => '确定';

  @override
  String pdfToImagesComplete(int count) {
    return 'PDF 转图片完成，共导出 $count 张';
  }

  @override
  String get imagesToPdfComplete => '图片合并 PDF 完成';

  @override
  String get compressPdfComplete => 'PDF 压缩完成';

  @override
  String extractPagesComplete(int count) {
    return 'PDF 提取页面完成（$count 页）';
  }

  @override
  String get watermarkDialogTitle => '水印参数';

  @override
  String get watermarkTextLabel => '水印文字';

  @override
  String get watermarkTextHint => '例如：防篡改-姓名-日期';

  @override
  String watermarkOpacityLabel(String value) {
    return '透明度: $value';
  }

  @override
  String watermarkAngleLabel(String value) {
    return '旋转角度: $value°';
  }

  @override
  String watermarkFontSizeLabel(String value) {
    return '字号: $value';
  }

  @override
  String get watermarkColorLabel => '颜色';

  @override
  String get watermarkColorDeepRed => '深红';

  @override
  String get watermarkColorDeepBlue => '深蓝';

  @override
  String get watermarkColorDeepGray => '深灰';

  @override
  String get watermarkColorBlack => '黑色';

  @override
  String get watermarkComplete => 'PDF 加水印完成';

  @override
  String get pdfToolsTitle => 'PDF 工具';

  @override
  String get recentTasksTitle => '最近任务';

  @override
  String recentTasksCount(int count) {
    return '$count 条记录';
  }

  @override
  String get copyOutputPath => '复制输出路径';

  @override
  String get outputPathCopied => '已复制输出路径';

  @override
  String get gueterToolsTitle => 'GUETer 工具';

  @override
  String get gueterToolsSubtitle => '收拢桂电常用官方入口';

  @override
  String get guetEmailTitle => '桂电邮箱';

  @override
  String get guetEmailSubtitle => '申请入口';

  @override
  String get guetOfficialTitle => '桂电官网';

  @override
  String get guetOfficialSubtitle => '学校主页';

  @override
  String get aiFigureTitle => 'AI 论文配图生成';

  @override
  String get aiFigureSubtitle => '输入方法描述，自动生成学术插图';

  @override
  String get settingsAnnouncementTitle => '设置公告';

  @override
  String get settingsAnnouncementContent =>
      '欢迎使用 GUETer。\n\n本项目仅提供本地化的学习辅助能力，不提供账号云端同步、密码代收或后台上传服务。\n\n账号、会话与相关本地记录采用加密后落盘保存；不会上传到本项目服务器，也不会主动发送你的账号密码。\n\n本公告为版本化提示，后续条款更新时会再次提示一次。\n\n如你所在学校、平台方或权利人对相关功能有异议，请以合规方式与我们联系处理。';

  @override
  String get reviewLaterButton => '稍后再看';

  @override
  String get gotItButton => '我已知晓';

  @override
  String get settingsSavedEmail => '学术 API 邮箱已保存';

  @override
  String get settingsClearedEmail => '学术 API 邮箱已清空';

  @override
  String get languageLabel => '语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRestartHint => '修改后重启应用生效';

  @override
  String get languageSavedRestart => '语言设置已保存，重启应用后生效';

  @override
  String get themeAndAppearanceTitle => '外观与主题';

  @override
  String get themeAndAppearanceSubtitle => '配色方案、主题风格、主题模式';

  @override
  String get themeModeLabel => '主题模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色护眼';

  @override
  String get themeStyleLabel => '主题风格';

  @override
  String get themeStyleModern => '现代（推荐）';

  @override
  String get themeStyleCompact => '紧凑';

  @override
  String get themeStylePlayful => '趣味';

  @override
  String get themeStyleMinimal => '极简';

  @override
  String get themeStyleBold => '大胆';

  @override
  String get themeStyleSoft => '柔和';

  @override
  String get randomPaletteTitle => '盲盒随机配色';

  @override
  String get randomPaletteSubtitle => '随机切换到一套不同的全局配色';

  @override
  String get academicToolsTitle => '学术工具';

  @override
  String get academicToolsSubtitle => 'CrossRef mailto 邮箱与论文检索相关配置';

  @override
  String get academicApiEmailLabel => '学术 API 邮箱';

  @override
  String get academicApiEmailHint => '可选，用于 CrossRef mailto 参数';

  @override
  String get academicApiEmailDescription =>
      '留空也可正常检索；填写后所有 CrossRef 请求会自动携带该邮箱，便于遵循其礼貌访问建议。';

  @override
  String get saveAcademicEmailTitle => '保存学术 API 邮箱';

  @override
  String get currentEmailUnset => '当前未设置邮箱';

  @override
  String currentEmailValue(String email) {
    return '当前邮箱: $email';
  }

  @override
  String get clearAcademicEmailTitle => '清空学术 API 邮箱';

  @override
  String get clearAcademicEmailSubtitle => '清空后 CrossRef 请求不再附带 mailto 参数';

  @override
  String get diagnosticsToggleTitle => '检查、诊断与修复工具';

  @override
  String get diagnosticsToggleSubtitle => '默认关闭，开启后可使用诊断功能';

  @override
  String get diagnosticsTitle => '检查、诊断与修复';

  @override
  String get diagnosticsSubtitle => '平台体检、报告导出与一键修复';

  @override
  String get checkPlatformsTitle => '检查四大平台连通性';

  @override
  String get checkPlatformsSubtitle => '学习通、雨课堂、畅课、课堂派';

  @override
  String get copyLastReportTooltip => '复制上次报告';

  @override
  String get lastReportCopied => '上次检查报告已复制';

  @override
  String get copyDiagnosticPackTitle => '生成诊断包并复制';

  @override
  String get copyDiagnosticPackSubtitle => '包含设置快照、账号统计、权限状态';

  @override
  String get fixCommonIssuesTitle => '一键修复常见问题';

  @override
  String get fixCommonIssuesSubtitle => '恢复推荐策略与默认平台地址';

  @override
  String get accountHealthTitle => '账号体检';

  @override
  String get accountHealthSubtitle => '检查四平台账号可用状态';

  @override
  String get batchPrecheckTitle => '批量签到预检';

  @override
  String get batchPrecheckSubtitle => '检查账号、权限、网络是否就绪';

  @override
  String get signRecordsTitle => '签到记录查询';

  @override
  String get signRecordsSubtitle => '按时间/平台/课程筛选，支持复制与分享';

  @override
  String get requestConsoleTitle => '请求控制台';

  @override
  String get requestConsoleSubtitle => '查看最近请求结果、重试与错误日志';

  @override
  String get securityAndPacingTitle => '安全与请求节奏';

  @override
  String get securityAndPacingSubtitle => '请求安全级别控制';

  @override
  String get strictSecurityModeTitle => '严格安全模式';

  @override
  String get strictSecurityModeSubtitle => '觉得可能请求过快的同学可以开启严格安全模式';

  @override
  String get securityLevelLabel => '请求安全级别：';

  @override
  String get securityLevelStrict => '严格';

  @override
  String get securityLevelStandard => '标准';

  @override
  String get securityModeStrictDescription => '当前模式：严格安全模式（签到类请求会额外降频）';

  @override
  String get securityModeStandardDescription => '当前模式：标准（默认）';

  @override
  String get beginnerGuideCardTitle => '新手引导';

  @override
  String get beginnerGuideCardSubtitle => '首次使用与常见排障建议';

  @override
  String get viewGuideButton => '查看引导内容';

  @override
  String get beginnerGuideDialogTitle => '新手引导（可关闭）';

  @override
  String get beginnerGuideDialogContent =>
      '1. 先选平台再登录，对应平台账号互不影响。\n\n2. 畅课建议用“系统浏览器优先 + 会话复用优先”。\n\n3. 签到前先跑一次“批量签到预检”。\n\n4. 异常时先点“一键修复常见问题”，再生成诊断包反馈。';

  @override
  String get quickActionsTitle => '快捷操作';

  @override
  String get quickActionPlatformCheck => '平台体检';

  @override
  String get quickActionFix => '一键修复';

  @override
  String get quickActionRandomPalette => '随机配色';

  @override
  String get disclaimerCardTitle => '免责声明（请先阅读）';

  @override
  String get disclaimerCardSubtitle => '本地加密存储，不上传服务器';

  @override
  String get disclaimerDialogTitle => '免责声明';

  @override
  String get disclaimerDialogSummary => '简要说明：本项目不代收账号密码，不做云端同步，账号数据仅加密保存在本机。';

  @override
  String get disclaimerDialogContent =>
      '免责声明（请先阅读）\n\n1. 本应用仅供学习交流与技术研究使用，不得用于任何违法违规用途。\n\n2. 本应用与学习通、雨课堂、畅课、课堂派、微助教等平台及其所属机构不存在官方合作关系。\n\n3. 用户应确保本人已获得对应平台账号与课程的合法使用授权，因个人操作导致的账号风险、数据损失或其他后果由用户自行承担。\n\n4. 本应用不提供账号云端同步、密码代收或后台上传服务；账号、会话与相关本地记录采用加密后落盘保存，不会上传到本项目服务器，也不会主动发送你的账号密码。\n\n5. 本应用不承诺服务连续可用，不对因网络波动、平台策略调整、接口变更、设备兼容问题导致的功能异常承担责任。\n\n6. 若你所在学校、平台方或权利人认为相关功能或展示内容存在不当，请及时联系我们处理。\n\n如有侵权请联系邮箱3177401522a@gmai.com';

  @override
  String get copyFullTextButton => '复制全文';

  @override
  String get disclaimerCopied => '免责声明已复制';

  @override
  String get themePaletteLabel => '配色方案';

  @override
  String get themePaletteLongPress => '长按切换';

  @override
  String get themeModeStatLabel => '主题模式';

  @override
  String themeModeSwitched(String mode) {
    return '已切换至$mode模式';
  }

  @override
  String colorSchemeSwitched(String name) {
    return '已切换配色：$name';
  }

  @override
  String randomPaletteSwitched(String name) {
    return '已切换盲盒配色：$name';
  }

  @override
  String get colorSchemeAqua => '青碧';

  @override
  String get colorSchemeOcean => '海蓝';

  @override
  String get colorSchemeForest => '松绿';

  @override
  String get colorSchemeAmber => '琥珀';

  @override
  String get colorSchemeNight => '护眼夜色';

  @override
  String get colorSchemeRose => '暖红';

  @override
  String get colorSchemePurple => '紫罗兰';

  @override
  String get colorSchemeCyan => '青色';

  @override
  String get colorSchemeOrange => '活力橙';

  @override
  String get autoCloseWebLoginTitle => '网页登录成功后自动返回';

  @override
  String get autoCloseWebLoginSubtitle => '畅课网页登录拿到会话后自动关闭页面';

  @override
  String get batchPrecheckResultTitle => '批量签到预检结果';

  @override
  String get copyReportButton => '复制报告';

  @override
  String get closeButton => '关闭';

  @override
  String get precheckReportCopied => '预检报告已复制';

  @override
  String get copyButton => '复制';

  @override
  String get passwordCopied => '密码已复制到剪贴板';

  @override
  String get computerHelpTitle => '电脑速查手册';

  @override
  String get computerHelpSubtitle => '离线内置 Windows 和安卓常见问题步骤卡';

  @override
  String get computerHelpPageTitle => '电脑速查手册';

  @override
  String get computerHelpSearchHint => '按问题标题或关键词搜索';

  @override
  String get computerHelpAllCategories => '问题分类';

  @override
  String get computerHelpAllPlatforms => '适用平台';

  @override
  String get computerHelpPlatformBoth => '双端';

  @override
  String get computerHelpPlatformWindows => 'Windows';

  @override
  String get computerHelpPlatformAndroid => '安卓';

  @override
  String get computerHelpDiagnosisLabel => '适用场景';

  @override
  String get computerHelpStepsLabel => '操作步骤';

  @override
  String get computerHelpTipsLabel => '常见误区与提示';

  @override
  String get computerHelpKeywordsLabel => '关键词';

  @override
  String get computerHelpCopySteps => '复制步骤';

  @override
  String get computerHelpCopyKeywords => '复制关键词';

  @override
  String get computerHelpCopiedSteps => '已复制步骤';

  @override
  String get computerHelpCopiedKeywords => '已复制关键词';

  @override
  String get computerHelpEmptyState => '暂时没有匹配的速查条目';

  @override
  String get computerHelpViewDetails => '查看步骤';

  @override
  String get computerHelpCategoryFileTransfer => '文件互传';

  @override
  String get computerHelpCategoryArchives => '压缩包';

  @override
  String get computerHelpCategoryFileBasics => '文件名与扩展名';

  @override
  String get computerHelpCategoryPdf => 'PDF';

  @override
  String get computerHelpCategoryCaptureProjection => '截图录屏与投屏';

  @override
  String get computerHelpCategorySoftwareInstall => '软件下载与安装';

  @override
  String get computerHelpCategoryDownloads => '浏览器下载';

  @override
  String get computerHelpCategoryDeviceConnection => 'U 盘 / 蓝牙 / 微信传文件';

  @override
  String get computerHelpCategoryNetworkBlock => '被拦截的下载';
}
