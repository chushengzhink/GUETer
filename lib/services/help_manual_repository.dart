import '../models/help_manual_models.dart';

class HelpManualRepository {
  const HelpManualRepository();

  List<HelpArticle> loadArticles() {
    return List<HelpArticle>.unmodifiable(_articles);
  }

  List<HelpArticle> searchArticles({
    String query = '',
    HelpCategory? category,
    HelpPlatformTag? platform,
    bool dualPlatformOnly = false,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    return _articles
        .where((article) {
          if (category != null && article.category != category) {
            return false;
          }
          if (dualPlatformOnly && !article.supportsBothPlatforms) {
            return false;
          }
          if (platform != null && !article.platforms.contains(platform)) {
            return false;
          }
          if (normalizedQuery.isEmpty) {
            return true;
          }

          final haystacks = <String>[
            article.title,
            article.diagnosis,
            ...article.steps,
            ...article.tips,
            ...article.keywords,
          ];

          return haystacks.any(
            (value) => value.toLowerCase().contains(normalizedQuery),
          );
        })
        .toList(growable: false);
  }
}

const List<HelpArticle> _articles = <HelpArticle>[
  HelpArticle(
    id: 'phone-pc-transfer',
    title: '手机和电脑怎么互传文件',
    category: HelpCategory.fileTransfer,
    platforms: {HelpPlatformTag.windows, HelpPlatformTag.android},
    diagnosis: '适合“线在手里但不知道怎么传”或者“微信传了找不到原文件”的情况。',
    steps: <String>[
      '先判断你要传的是几张图片、一个大视频，还是整份资料夹。',
      '小文件优先用微信文件传输助手，发送后在电脑微信里右键另存为。',
      '大文件优先用数据线连接手机和电脑，手机上点“传输文件”而不是“仅充电”。',
      '在 Windows 资源管理器里打开“此电脑”，进入手机存储后再复制到电脑文件夹。',
      '如果电脑识别不到手机，先换一根支持传数据的数据线，再重插一次。',
      '不想插线时，可以用你工具页里的本地传输功能，在同一近场环境下直接互传。',
    ],
    tips: <String>[
      '很多线只能充电，不能传数据。',
      '微信会压缩图片，原图资料不要只靠聊天窗口中转。',
      '传完后记得在目标文件夹里实际打开一次，确认不是空文件。',
    ],
    keywords: <String>['手机传电脑', '数据线', '微信文件传输助手', '本地传输'],
  ),
  HelpArticle(
    id: 'zip-open',
    title: '压缩包打不开怎么办',
    category: HelpCategory.archives,
    platforms: {HelpPlatformTag.windows},
    diagnosis: '适合双击 ZIP 没反应、提示未知格式，或者下载的资料包解不开。',
    steps: <String>[
      '先看文件后缀是不是 `.zip`，如果不是，本工具首版不支持 RAR 或 7z。',
      '右键压缩包，先尝试系统自带“全部解压缩”。',
      '如果系统提示文件损坏，回到下载来源重新下载一次，很多情况是下载没完成。',
      '如果资料名很长或路径太深，把 ZIP 先移动到桌面再解压。',
      '如果还是打不开，进工具页的文件工具，用 ZIP 解压功能再试一次。',
    ],
    tips: <String>['把 `.rar` 改名成 `.zip` 一般没有用。', '网盘预览下载失败时，经常会得到一个不完整压缩包。'],
    keywords: <String>['ZIP', '解压', '压缩包损坏', '打不开'],
  ),
  HelpArticle(
    id: 'filename-extension',
    title: '文件名、扩展名、后缀名是什么',
    category: HelpCategory.fileBasics,
    platforms: {HelpPlatformTag.windows},
    diagnosis: '适合“老师说改后缀”“为什么改名后还是打不开”“两个文件看着一样”的情况。',
    steps: <String>[
      '文件名通常分成两部分：前面是名称主体，最后一个点后面是扩展名。',
      '在 Windows 资源管理器里打开任意文件夹，点“查看”并开启“文件扩展名”。',
      '看到 `.pdf`、`.docx`、`.zip` 这些后缀后，再决定要不要改名。',
      '如果只是想改标题，改点前面的部分就行。',
      '如果确实要改扩展名，先确认你知道原文件类型，再去工具页的文件工具里单独编辑扩展名。',
    ],
    tips: <String>['随便改扩展名不会把文件真正转换格式。', '同名不同后缀的文件不是同一个东西。'],
    keywords: <String>['扩展名', '后缀名', '改名', '文件类型'],
  ),
  HelpArticle(
    id: 'pdf-basics',
    title: 'PDF 怎么打开、合并、压缩',
    category: HelpCategory.pdf,
    platforms: {HelpPlatformTag.windows, HelpPlatformTag.android},
    diagnosis: '适合“作业要合并 PDF”“文件太大发不出去”“手机能看电脑不能看”的情况。',
    steps: <String>[
      '先双击试着打开，如果打不开，优先看是不是文件没下载完整。',
      '如果你手里是多张图片，进工具页 PDF 工具，用“图片合并 PDF”。',
      '如果你有多个 PDF，先在电脑上整理好顺序，再用已有 PDF 工具逐个处理。',
      '如果老师限制上传大小，优先用“PDF 压缩”而不是反复截图转图片。',
      '发送前先自己打开一次压缩后的 PDF，确认文字没有糊掉。',
    ],
    tips: <String>['截图再转 PDF 往往最糊，也最难搜索文字。', '压缩过度会让扫描件和盖章页变得很难看清。'],
    keywords: <String>['PDF', '合并', '压缩', '打不开'],
  ),
  HelpArticle(
    id: 'capture-record-cast',
    title: '截图、录屏、投屏怎么做',
    category: HelpCategory.captureProjection,
    platforms: {HelpPlatformTag.windows, HelpPlatformTag.android},
    diagnosis: '适合上课要交截图、录操作过程，或者想把手机画面投到电脑/大屏。',
    steps: <String>[
      'Windows 截图直接按 `Win + Shift + S`，拖动选区后去剪贴板或通知里保存。',
      'Windows 录屏优先用 `Win + G` 打开 Xbox Game Bar，再点录制。',
      '安卓长截图通常在截屏后出现“滚动截屏”按钮，不同品牌位置略有区别。',
      '安卓录屏一般在下拉快捷开关里，先允许录制麦克风或系统声音。',
      '投屏前先确认接收端支持什么协议，不同教室大屏和电脑差别很大。',
      '如果只是把手机文件放到电脑看，优先传文件，不要强行实时投屏。',
    ],
    tips: <String>['有些应用会限制录屏黑屏，这不是你操作错了。', '投屏卡顿时先关蓝牙耳机和高码率视频，减少无线干扰。'],
    keywords: <String>['截图', '录屏', '投屏', 'Win+Shift+S', 'Game Bar'],
  ),
  HelpArticle(
    id: 'software-install',
    title: '软件下载安装到哪里，怎么判断来源',
    category: HelpCategory.softwareInstall,
    platforms: {HelpPlatformTag.windows, HelpPlatformTag.android},
    diagnosis: '适合“下载完不知道点哪个”“怕装到奇怪的软件”“安装包太多分不清”的情况。',
    steps: <String>[
      '先确认软件来源是不是官网、老师给的官方页面，或者可信应用商店。',
      'Windows 上下载到的安装包通常先在“下载”文件夹，文件名里常见 `setup`、`installer`、`.msi`、`.exe`。',
      '安卓安装包一般是 `.apk`，安装前要看包名、开发者和权限提示。',
      '安装时别一路无脑下一步，留意是否有捆绑勾选项。',
      '装完马上打开一次，确认是你要的软件，再把旧安装包整理到单独文件夹。',
    ],
    tips: <String>['“高速下载器”“安全下载”这类二次封装页面尽量避开。', '软件能正常用后，安装包不必一直堆在桌面。'],
    keywords: <String>['安装包', '官网下载', 'apk', 'exe', 'msi'],
  ),
  HelpArticle(
    id: 'browser-downloads',
    title: '浏览器下载的文件到底在哪',
    category: HelpCategory.downloads,
    platforms: {HelpPlatformTag.windows, HelpPlatformTag.android},
    diagnosis: '适合“明明下载成功了但找不到”“浏览器里能看到，文件管理里看不到”的情况。',
    steps: <String>[
      '先去浏览器下载记录里找这条文件，点“打开所在位置”或“在文件夹中显示”。',
      'Windows 默认一般在 `下载` 文件夹，也可能在浏览器单独设置的目录。',
      '安卓通常在“下载/Download”目录，部分浏览器会放到自己的专用文件夹。',
      '如果文件名太长不好找，用文件管理器搜索文件名中的两个关键字。',
      '以后下载前先看浏览器底部或弹窗给的保存位置，别下完再猜。',
    ],
    tips: <String>['重复下载时，系统常会自动加 `(1)`、`(2)`。', '有些网盘会先下一个小的启动文件，不是真正资料本体。'],
    keywords: <String>['下载位置', '浏览器下载', 'Download', '找不到文件'],
  ),
  HelpArticle(
    id: 'u-disk-bluetooth-wechat',
    title: 'U 盘、蓝牙、微信文件传输助手怎么选',
    category: HelpCategory.deviceConnection,
    platforms: {HelpPlatformTag.windows, HelpPlatformTag.android},
    diagnosis: '适合“有很多种传文件方式，但不知道哪种最稳最省事”的情况。',
    steps: <String>[
      '几百 MB 到几 GB 的资料，优先用 U 盘或数据线，速度最稳。',
      '几张图、一个文档，优先用微信文件传输助手，操作最省心。',
      '蓝牙更适合小文件和临时发送，不适合大视频。',
      'U 盘插上没反应时，先换一个 USB 口，再看资源管理器里有没有新盘符。',
      '蓝牙发文件前先完成配对，再在 Windows 蓝牙设置里找“发送或接收文件”。',
    ],
    tips: <String>['拔 U 盘前尽量先关闭正在打开的文件。', '微信传输助手适合中小文件，不适合长期当网盘。'],
    keywords: <String>['U盘', '蓝牙', '微信文件传输助手', '传文件'],
  ),
  HelpArticle(
    id: 'blocked-downloads',
    title: 'GitHub、网盘、安装包被系统拦截怎么办',
    category: HelpCategory.networkBlock,
    platforms: {HelpPlatformTag.windows},
    diagnosis: '适合下载后提示“已阻止”“不常见文件”“Windows 已保护你的电脑”的情况。',
    steps: <String>[
      '先判断来源是否可信，确认是官网、课程群正规链接或你自己熟悉的项目页面。',
      '如果浏览器提示不常见文件，先看文件后缀和大小是否符合预期。',
      'Windows SmartScreen 拦截时，不要立刻强行运行，先右键文件看属性和签名信息。',
      '如果确认来源可信，再按系统提示展开“更多信息”后继续。',
      '来自 GitHub 的压缩包优先先解压再看内容，别对陌生脚本直接双击。',
    ],
    tips: <String>['“能绕过拦截”不等于“这个文件安全”。', '如果老师只给了网盘口令，没有说明文件用途，先问清楚再运行。'],
    keywords: <String>['GitHub 下载', '网盘拦截', 'SmartScreen', '已阻止'],
  ),
];
