import 'dart:convert';

class PluginTemplate {
  const PluginTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.manifest,
    this.readme = '',
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final Map<String, Object?> manifest;
  final String readme;

  String get directoryName => id;

  String manifestJson() {
    return const JsonEncoder.withIndent('  ').convert(manifest);
  }
}

class PluginTemplateLibrary {
  const PluginTemplateLibrary();

  List<PluginTemplate> all() {
    return const <PluginTemplate>[
      PluginTemplate(
        id: 'gueter.template.copy-path',
        title: '文件预览复制路径',
        description: '在文件预览页复制当前文件路径。',
        category: '文件动作',
        manifest: <String, Object?>{
          'manifestVersion': 2,
          'id': 'gueter.template.copy-path',
          'name': <String, String>{'zh': '复制文件路径', 'en': 'Copy File Path'},
          'version': '1.0.0',
          'author': 'GUETer',
          'description': <String, String>{
            'zh': '文件预览页动作模板。',
            'en': 'File preview action template.',
          },
          'capabilities': <String>['filePreviewAction'],
          'permissions': <String>['clipboard'],
          'entries': <Object>[
            <String, Object?>{
              'id': 'copy-path',
              'name': <String, String>{'zh': '复制路径', 'en': 'Copy Path'},
              'description': <String, String>{
                'zh': '复制当前文件路径。',
                'en': 'Copy current file path.',
              },
              'icon': 'copy',
              'slots': <String>['filePreview'],
              'contexts': <String>['file'],
              'action': <String, Object?>{
                'type': 'copyText',
                'text': '{filePath}',
              },
            },
          ],
        },
      ),
      PluginTemplate(
        id: 'gueter.template.study-card',
        title: '资料转复习卡片',
        description: '把当前文件作为来源创建复习卡片。',
        category: '学习工作流',
        manifest: <String, Object?>{
          'manifestVersion': 2,
          'id': 'gueter.template.study-card',
          'name': <String, String>{'zh': '资料转复习卡片', 'en': 'Study Card'},
          'version': '1.0.0',
          'author': 'GUETer',
          'description': <String, String>{
            'zh': '把文件预览上下文保存为复习卡片。',
            'en': 'Create a study card from the file context.',
          },
          'capabilities': <String>['filePreviewAction', 'toolEntry'],
          'permissions': <String>['localFileRead'],
          'entries': <Object>[
            <String, Object?>{
              'id': 'make-card',
              'name': <String, String>{'zh': '生成复习卡片', 'en': 'Create Card'},
              'description': <String, String>{
                'zh': '使用当前文件名和路径创建复习卡片。',
                'en': 'Use current file name and path to create a card.',
              },
              'icon': 'save',
              'slots': <String>['filePreview'],
              'contexts': <String>['file'],
              'action': <String, Object?>{
                'type': 'openWithFileTool',
                'toolAction': 'studyCard',
              },
            },
            <String, Object?>{
              'id': 'open-center',
              'name': <String, String>{'zh': '打开复习中心', 'en': 'Open Review'},
              'description': <String, String>{
                'zh': '进入本地复习中心。',
                'en': 'Open local review center.',
              },
              'icon': 'tool',
              'slots': <String>['tool', 'command'],
              'action': <String, Object?>{
                'type': 'openBuiltinTool',
                'tool': 'studyCards',
              },
            },
          ],
        },
      ),
      PluginTemplate(
        id: 'gueter.template.health',
        title: '打开健康中心',
        description: '提供工具入口和健康中心动作入口。',
        category: '健康中心',
        manifest: <String, Object?>{
          'manifestVersion': 2,
          'id': 'gueter.template.health',
          'name': <String, String>{'zh': '健康中心入口', 'en': 'Health Center'},
          'version': '1.0.0',
          'author': 'GUETer',
          'description': <String, String>{
            'zh': '打开诊断修复中心。',
            'en': 'Open diagnostics center.',
          },
          'capabilities': <String>['toolEntry', 'healthAction'],
          'permissions': <String>[],
          'entries': <Object>[
            <String, Object?>{
              'id': 'health',
              'name': <String, String>{'zh': '诊断修复', 'en': 'Diagnostics'},
              'description': <String, String>{
                'zh': '打开诊断修复中心。',
                'en': 'Open diagnostics center.',
              },
              'icon': 'health',
              'slots': <String>['tool', 'health', 'command'],
              'action': <String, Object?>{'type': 'openHealthCenter'},
            },
          ],
        },
      ),
      PluginTemplate(
        id: 'gueter.template.local-transfer',
        title: '局域网发送当前文件',
        description: '把文件预览中的当前文件交给局域网快传。',
        category: '文件动作',
        manifest: <String, Object?>{
          'manifestVersion': 2,
          'id': 'gueter.template.local-transfer',
          'name': <String, String>{'zh': '局域网发送', 'en': 'LAN Send'},
          'version': '1.0.0',
          'author': 'GUETer',
          'description': <String, String>{
            'zh': '发送当前文件到局域网设备。',
            'en': 'Send current file to LAN devices.',
          },
          'capabilities': <String>['filePreviewAction'],
          'permissions': <String>['localFileRead'],
          'entries': <Object>[
            <String, Object?>{
              'id': 'send-file',
              'name': <String, String>{'zh': '局域网发送', 'en': 'LAN Send'},
              'description': <String, String>{
                'zh': '发送当前文件。',
                'en': 'Send current file.',
              },
              'icon': 'share',
              'slots': <String>['filePreview'],
              'contexts': <String>['file'],
              'action': <String, Object?>{'type': 'sendToLocalTransfer'},
            },
          ],
        },
      ),
      PluginTemplate(
        id: 'gueter.template.file-note',
        title: '保存文件备注',
        description: '把当前文件名保存到插件私有备注文件。',
        category: '工作流',
        manifest: <String, Object?>{
          'manifestVersion': 2,
          'id': 'gueter.template.file-note',
          'name': <String, String>{'zh': '文件备注', 'en': 'File Note'},
          'version': '1.0.0',
          'author': 'GUETer',
          'description': <String, String>{
            'zh': '在插件私有目录保存文件备注。',
            'en': 'Save file notes in plugin private storage.',
          },
          'capabilities': <String>['filePreviewAction'],
          'permissions': <String>['localFileWrite'],
          'entries': <Object>[
            <String, Object?>{
              'id': 'save-note',
              'name': <String, String>{'zh': '保存备注', 'en': 'Save Note'},
              'description': <String, String>{
                'zh': '保存当前文件的备注文本。',
                'en': 'Save a note for current file.',
              },
              'icon': 'save',
              'slots': <String>['filePreview'],
              'contexts': <String>['file'],
              'action': <String, Object?>{
                'type': 'saveTextFile',
                'fileName': '{fileName}.note.txt',
                'text': '文件：{fileName}\\n路径：{filePath}',
              },
            },
          ],
        },
      ),
      PluginTemplate(
        id: 'gueter.template.http-get',
        title: 'HTTP GET 展示结果',
        description: '请求公开接口并展示文本结果，默认限制到示例域名。',
        category: '网络',
        manifest: <String, Object?>{
          'manifestVersion': 2,
          'id': 'gueter.template.http-get',
          'name': <String, String>{'zh': 'HTTP GET 示例', 'en': 'HTTP GET'},
          'version': '1.0.0',
          'author': 'GUETer',
          'description': <String, String>{
            'zh': '展示公开 HTTP GET 结果。',
            'en': 'Show public HTTP GET response.',
          },
          'capabilities': <String>['toolEntry'],
          'permissions': <String>['network'],
          'allowedHosts': <String>['example.com'],
          'settingsSchema': <Object>[
            <String, Object?>{
              'id': 'url',
              'type': 'text',
              'label': <String, String>{'zh': '请求 URL', 'en': 'Request URL'},
              'defaultValue': 'https://example.com',
            },
          ],
          'entries': <Object>[
            <String, Object?>{
              'id': 'get',
              'name': <String, String>{'zh': '请求并展示', 'en': 'Fetch'},
              'description': <String, String>{
                'zh': '发送 GET 请求并展示结果。',
                'en': 'Send GET request and show result.',
              },
              'icon': 'http',
              'slots': <String>['tool', 'command'],
              'action': <String, Object?>{
                'type': 'httpRequest',
                'method': 'GET',
                'url': '{setting.url}',
              },
            },
          ],
        },
      ),
    ];
  }
}
