enum OpenListAccountMode { readonly, personal }

class OpenListCredentials {
  const OpenListCredentials({
    required this.mode,
    required this.username,
    required this.password,
  });

  final OpenListAccountMode mode;
  final String username;
  final String password;

  String get label => switch (mode) {
    OpenListAccountMode.readonly => 'gueter_readonly',
    OpenListAccountMode.personal => 'gueter_personal',
  };
}

class OpenListSession {
  const OpenListSession({
    required this.mode,
    required this.token,
    required this.username,
    required this.permission,
    required this.basePath,
  });

  final OpenListAccountMode mode;
  final String token;
  final String username;
  final int permission;
  final String basePath;

  OpenListPermission get permissions => OpenListPermission(permission);

  bool get isReadWrite => mode == OpenListAccountMode.personal;
  bool get canUpload => permissions.canWriteContent;
  bool get canShare => isReadWrite && permissions.canShare;
}

class OpenListPermission {
  const OpenListPermission(this.value);

  final int value;

  bool hasBit(int index) => ((value >> index) & 1) == 1;

  bool get canSeeHidden => hasBit(0);
  bool get canAccessWithoutPassword => hasBit(1);
  bool get canAddOfflineDownloadTasks => hasBit(2);
  bool get canWriteContent => hasBit(3);
  bool get canRename => hasBit(4);
  bool get canMove => hasBit(5);
  bool get canCopy => hasBit(6);
  bool get canRemove => hasBit(7);
  bool get canWebDavRead => hasBit(8);
  bool get canWebDavManage => hasBit(9);
  bool get canFtpAccess => hasBit(10);
  bool get canFtpManage => hasBit(11);
  bool get canReadArchives => hasBit(12);
  bool get canDecompress => hasBit(13);
  bool get canShare => hasBit(14);
  bool get canCustomizeShareId => hasBit(15);

  List<int> get enabledBits {
    return [
      for (var i = 0; i <= 15; i++)
        if (hasBit(i)) i,
    ];
  }
}

class OpenListUserProfile {
  const OpenListUserProfile({
    required this.username,
    required this.permission,
    required this.basePath,
    required this.disabled,
  });

  final String username;
  final int permission;
  final String basePath;
  final bool disabled;

  factory OpenListUserProfile.fromJson(Map<String, dynamic> json) {
    return OpenListUserProfile(
      username: json['username']?.toString() ?? '',
      permission: _intValue(json['permission']),
      basePath: json['base_path']?.toString() ?? '/',
      disabled: json['disabled'] == true,
    );
  }
}

class OpenListFileItem {
  const OpenListFileItem({
    required this.name,
    required this.size,
    required this.isDir,
    required this.modified,
    required this.created,
    required this.sign,
    required this.thumb,
    required this.type,
  });

  final String name;
  final int size;
  final bool isDir;
  final DateTime? modified;
  final DateTime? created;
  final String sign;
  final String thumb;
  final int type;

  factory OpenListFileItem.fromJson(Map<String, dynamic> json) {
    return OpenListFileItem(
      name: json['name']?.toString() ?? '',
      size: _intValue(json['size']),
      isDir: json['is_dir'] == true,
      modified: _dateValue(json['modified']),
      created: _dateValue(json['created']),
      sign: json['sign']?.toString() ?? '',
      thumb: json['thumb']?.toString() ?? '',
      type: _intValue(json['type']),
    );
  }
}

class OpenListDirectoryListing {
  const OpenListDirectoryListing({
    required this.content,
    required this.total,
    required this.write,
    required this.provider,
    required this.readme,
    required this.header,
  });

  final List<OpenListFileItem> content;
  final int total;
  final bool write;
  final String provider;
  final String readme;
  final String header;

  bool get isEmpty => content.isEmpty;

  factory OpenListDirectoryListing.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final items = rawContent is List
        ? rawContent
              .whereType<Map>()
              .map(
                (item) => OpenListFileItem.fromJson(
                  item.map((key, value) => MapEntry('$key', value)),
                ),
              )
              .where((item) => item.name.isNotEmpty)
              .toList()
        : <OpenListFileItem>[];
    items.sort((a, b) {
      if (a.isDir != b.isDir) {
        return a.isDir ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return OpenListDirectoryListing(
      content: items,
      total: _intValue(json['total']),
      write: json['write'] == true,
      provider: json['provider']?.toString() ?? '',
      readme: json['readme']?.toString() ?? '',
      header: json['header']?.toString() ?? '',
    );
  }
}

class OpenListFileDetail {
  const OpenListFileDetail({
    required this.name,
    required this.size,
    required this.isDir,
    required this.rawUrl,
  });

  final String name;
  final int size;
  final bool isDir;
  final String rawUrl;

  factory OpenListFileDetail.fromJson(Map<String, dynamic> json) {
    return OpenListFileDetail(
      name: json['name']?.toString() ?? '',
      size: _intValue(json['size']),
      isDir: json['is_dir'] == true,
      rawUrl: json['raw_url']?.toString() ?? '',
    );
  }
}

class OpenListShareInfo {
  const OpenListShareInfo({
    required this.id,
    required this.files,
    required this.url,
  });

  final String id;
  final List<String> files;
  final String url;

  factory OpenListShareInfo.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final filesRaw = json['files'];
    final files = filesRaw is List
        ? filesRaw.map((item) => item.toString()).toList()
        : <String>[];
    final id = json['id']?.toString() ?? '';
    return OpenListShareInfo(
      id: id,
      files: files,
      url: id.isEmpty
          ? ''
          : '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/sd/$id',
    );
  }
}

class OpenListUploaderIdentity {
  const OpenListUploaderIdentity({
    required this.studentId,
    required this.studentName,
  });

  final String studentId;
  final String studentName;
}

class OpenListUserProvisionProof {
  const OpenListUserProvisionProof({
    required this.accountUid,
    required this.studentId,
    required this.studentName,
    required this.sessionId,
    required this.cookie,
  });

  final String accountUid;
  final String studentId;
  final String studentName;
  final String sessionId;
  final String cookie;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accountUid': accountUid,
      'studentId': studentId,
      'studentName': studentName,
      if (sessionId.trim().isNotEmpty) 'sessionId': sessionId.trim(),
      if (cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
    };
  }
}

class OpenListProvisionedUser {
  const OpenListProvisionedUser({
    required this.username,
    required this.password,
    required this.studentId,
    required this.studentName,
    required this.permission,
    required this.basePath,
  });

  final String username;
  final String password;
  final String studentId;
  final String studentName;
  final int permission;
  final String basePath;

  factory OpenListProvisionedUser.fromJson(Map<String, dynamic> json) {
    return OpenListProvisionedUser(
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? '',
      permission: _intValue(json['permission']),
      basePath: json['basePath']?.toString() ?? '/',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      'password': password,
      'studentId': studentId,
      'studentName': studentName,
      'permission': permission,
      'basePath': basePath,
    };
  }
}

class OpenListUploadAuditRecord {
  const OpenListUploadAuditRecord({
    required this.studentId,
    required this.studentName,
    required this.remotePath,
    required this.fileName,
    required this.size,
    required this.uploadedAt,
    required this.openListUsername,
    required this.permission,
    required this.clientPlatform,
    this.source = 'app',
    this.requestMethod = '',
  });

  final String studentId;
  final String studentName;
  final String remotePath;
  final String fileName;
  final int size;
  final DateTime uploadedAt;
  final String openListUsername;
  final int permission;
  final String clientPlatform;
  final String source;
  final String requestMethod;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'studentId': studentId,
      'studentName': studentName,
      'remotePath': remotePath,
      'fileName': fileName,
      'size': size,
      'uploadedAt': uploadedAt.toUtc().toIso8601String(),
      'openListUsername': openListUsername,
      'permission': permission,
      'clientPlatform': clientPlatform,
      'source': source,
      if (requestMethod.isNotEmpty) 'requestMethod': requestMethod,
    };
  }

  factory OpenListUploadAuditRecord.fromJson(Map<String, dynamic> json) {
    return OpenListUploadAuditRecord(
      studentId: json['studentId']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? '',
      remotePath: json['remotePath']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      size: _intValue(json['size']),
      uploadedAt:
          DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      openListUsername: json['openListUsername']?.toString() ?? '',
      permission: _intValue(json['permission']),
      clientPlatform: json['clientPlatform']?.toString() ?? '',
      source: json['source']?.toString() ?? 'app',
      requestMethod: json['requestMethod']?.toString() ?? '',
    );
  }
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateValue(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}
