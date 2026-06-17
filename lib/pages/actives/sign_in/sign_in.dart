import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import '../../../api/chaoxing_sign_api.dart';
import '../../../api/api_service.dart';
import '../../../models/user.dart';
import '../../../models/active.dart';
import '../../../platform.dart';
import '../../../session/account.dart';
import '../../../session/sign_record_store.dart';
import '../../../services/sign_network_gate.dart';
import '../../../services/sign_platform_context.dart';
import '../../../services/sign_run_console.dart';
import '../../../widgets/sign_run_console_panel.dart';
import '../../../setting/course_setting.dart';
import '../../widget/accounts_selector.dart';
import '../../widget/captcha.dart';
import 'normal.dart';
import 'pattern.dart';
import 'code.dart';
import 'qrcode.dart';
import 'location.dart';

class SignParams {
  final Active active;
  final String courseId;
  final String classId;
  final String cpi;

  // 普通签到（拍照）
  final Map<String, String> _userObjectIds = {}; // userId -> objectId

  // 手势签到
  String pattern = '';

  // 签到码签到
  String code = '';
  int numberCount = 0;

  // 二维码签到
  String? enc;
  String? qrCodeData;

  // 位置签到
  String? address;
  double? latitude;
  double? longitude;

  SignParams({
    required this.active,
    required this.courseId,
    required this.classId,
    required this.cpi,
  });

  // 照片ID管理
  void setUserObjectId(String userId, String objectId) {
    _userObjectIds[userId] = objectId;
  }

  String? getUserObjectId(String userId) {
    return _userObjectIds[userId];
  }

  void setUserObjectIds(Map<String, String> objectIds) {
    _userObjectIds.addAll(objectIds);
  }

  Map<String, String> getAllUserObjectIds() {
    return Map.unmodifiable(_userObjectIds);
  }

  int get photoCount => _userObjectIds.length;
}

abstract class SignStrategy {
  /// 执行签到流程（UI交互+签到准备）
  Future<void> execute(
    BuildContext context,
    SignInPageState state,
    SignParams params,
  );

  /// 为单个账号执行签到（批量签到使用）
  Future<String?> signForAccount(
    User user,
    SignParams params,
    SignInPageState state,
  );
}

class SignStrategyFactory {
  static SignStrategy? create(SignType? type) {
    switch (type) {
      case SignType.normal:
        return NormalSign();
      case SignType.pattern:
        return PatternSign();
      case SignType.code:
        return CodeSign();
      case SignType.qrCode:
        return QRCodeSign();
      case SignType.location:
        return LocationSign();
      default:
        return null;
    }
  }
}

class SignInPage extends StatefulWidget {
  final Active active;
  final String courseId;
  final String classId;
  final String cpi;
  final String? enc;

  const SignInPage({
    super.key,
    required this.active,
    required this.courseId,
    required this.classId,
    required this.cpi,
    this.enc,
  });

  @override
  State<SignInPage> createState() => SignInPageState();
}

class SignInPageState extends State<SignInPage> {
  static const String _networkSkippedResultPrefix = '__network_skipped__:';

  // 签到策略
  SignStrategy? _currentStrategy;
  late SignParams _signParams;
  final SignRunConsoleController _consoleController = SignRunConsoleController(
    platformContext: SignPlatformContext.chaoxing,
  );

  int _signTypeId = 0;

  int _status = 0;

  // 签到状态管理
  bool _isLoading = false;
  bool _isMultiSigning = false;
  bool _isDataLoaded = false;

  // 签到数据
  bool _needCaptcha = false;
  bool _needFace = false;
  bool _needPhoto = false;
  String? _locationRange;
  String? _designatedPlace;

  // 签到码相关
  final List<TextEditingController> _codeControllers = [];

  // 账号选择
  List<User> _selectedAccounts = [];
  User? _currentUser;
  final GlobalKey<State<AccountsSelector>> _accountsSelectorKey =
      GlobalKey<State<AccountsSelector>>();

  // UserId -> {Validate, enc2}
  final Map<String, Map<String, String>> _userCaptchaValidate = {};

  // Getter
  bool get needPhoto => _needPhoto;
  bool get needFace => _needFace;
  String? get designatedPlace => _designatedPlace;
  String? get locationRange => _locationRange;
  List<User> get selectedAccounts => _selectedAccounts;
  User? get currentUser => _currentUser;
  SignStrategy? get currentStrategy => _currentStrategy;
  SignParams get signParams => _signParams;

  Map<String, String>? getUserCaptchaValidate(String userId) {
    return _userCaptchaValidate[userId];
  }

  void setUserImage(String uid, File imageFile) {
    // 账号选择器状态更新（可选实现）
    if (mounted) setState(() {});
  }

  void setUserUploadingStatus(String uid, bool isUploading) {
    // 账号选择器状态更新（可选实现）
    if (mounted) setState(() {});
  }

  void setUserUploadFailed(String uid) {
    // 账号选择器状态更新（可选实现）
    if (mounted) setState(() {});
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final currentSessionId = AccountManager.currentSessionId!;
    _currentUser = AccountManager.getAccountById(currentSessionId);

    _signParams = SignParams(
      active: widget.active,
      courseId: widget.courseId,
      classId: widget.classId,
      cpi: widget.cpi,
    );

    // 扫码签到
    if (widget.enc != null) {
      _signParams.enc = widget.enc;
    }

    _loadActivityData();
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    _consoleController.dispose();
    super.dispose();
  }

  Future<void> _parseSignInfo() async {
    try {
      final results = await Future.wait([
        ChaoxingSignApi.getActiveInfoWeb(widget.active.id),
        ChaoxingSignApi.getAttendInfoWeb(widget.active.id),
      ]);

      final activeInfo = results[0];
      final attendInfo = results[1];

      if (activeInfo != null) {
        _signTypeId = activeInfo['otherId'];
        _needCaptcha = activeInfo['showVCode'] == 1;

        if (widget.active.signType == null) {
          widget.active.signType = getSignTypeFromIndex(_signTypeId);
        }

        switch (widget.active.signType) {
          case SignType.normal:
            _needPhoto = activeInfo['ifphoto'] == 1;
            break;
          case SignType.code:
            _signParams.numberCount = activeInfo['numberCount'];
            break;
          case SignType.qrCode:
          case SignType.location:
            _locationRange = activeInfo['locationRange'];
            _designatedPlace = activeInfo['locationText'];
            _needFace = activeInfo['openCheckFaceFlag'] == 1;
            break;
          case _:
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('获取活动信息失败')));
        }
      }
      if (attendInfo != null) {
        _status = attendInfo['status'];
        if (_status == 1) {
          _showSuccessMessage('当前用户已签到');
          if (_currentUser != null) {
            setState(() {
              _selectedAccounts.removeWhere(
                (user) => user.uid == _currentUser!.uid,
              );
            });
          }
        }
      }

      if (widget.active.signType == SignType.normal &&
          _needPhoto &&
          _selectedAccounts.isNotEmpty) {
        _assignImages();
      }
    } catch (e) {
      ApiService.appendExternalConsoleLog('学习通', '签到信息解析失败：$e');
    }
  }

  Future<void> _loadActivityData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    await _parseSignInfo();

    _currentStrategy = SignStrategyFactory.create(widget.active.signType);

    // 自动填充课程设置的位置
    if (widget.active.signType == SignType.location) {
      final settings = await CourseSetting.getSettings(widget.courseId);
      if (settings?.location != null) {
        _signParams.address = settings!.location!.address;
        _signParams.latitude = settings.location!.latitude;
        _signParams.longitude = settings.location!.longitude;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isDataLoaded = true;
    });

    if (_currentStrategy != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _currentStrategy!.execute(context, this, _signParams);
      });
    } else if (mounted) {
      _showErrorMessage('未知的签到类型');
    }
  }

  Future<void> _assignImages() async {
    final settings = await CourseSetting.getSettings(widget.courseId);
    if (settings?.imageObjectIds == null || settings!.imageObjectIds!.isEmpty) {
      return;
    }

    final imageIds = settings.imageObjectIds!;
    final objectIds = <String, String>{};

    for (int i = 0; i < _selectedAccounts.length; i++) {
      final user = _selectedAccounts[i];
      final imageId = imageIds[i % imageIds.length];
      objectIds[user.uid] = imageId;
    }

    _signParams.setUserObjectIds(objectIds);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.active.name),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.active.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // 签到操作区域 - 根据策略动态显示
                if (_currentStrategy != null) _buildSignOperationArea(),

                const SizedBox(height: 20),

                // 账号选择
                AccountsSelector(
                  key: _accountsSelectorKey,
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedAccounts = selected;
                    });
                    if (widget.active.signType == SignType.normal &&
                        _needPhoto) {
                      _assignImages();
                    }
                  },
                  title: '选择签到账号',
                ),

                const SizedBox(height: 20),

                SignRunConsolePanel(controller: _consoleController),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // 加载指示器
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('批量签到中...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  /// 根据签到策略构建对应的签到操作UI
  Widget _buildSignOperationArea() {
    switch (widget.active.signType) {
      case SignType.normal:
        return NormalSign.buildSignArea(this);
      case SignType.pattern:
        return PatternSign.buildSignArea(this);
      case SignType.code:
        return CodeSign.buildSignArea(this);
      case SignType.qrCode:
        return QRCodeSign.buildSignArea(this);
      case SignType.location:
        return LocationSign.buildSignArea(this);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _performMultiSign() async {
    if (_selectedAccounts.isEmpty || _currentStrategy == null) return;
    if (_isMultiSigning) return;

    setState(() {
      _isLoading = true;
      _isMultiSigning = true;
    });
    _consoleController.resetForPlatform(SignPlatformContext.chaoxing);

    final failedAccounts = <String>[];
    final totalCount = _selectedAccounts.length;

    final isQrCodeSign = widget.active.signType == SignType.qrCode;

    // 除二维码签到以外 其他签到预先处理验证码
    if (_needCaptcha && !isQrCodeSign) {
      for (var user in _selectedAccounts) {
        AccountManager.setCurrentSessionTemp(user.uid);

        if (!await _handleCaptcha(user.uid)) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isMultiSigning = false;
            });
          }
          _showErrorMessage('验证码取消或失败');
          return;
        }
      }
      AccountManager.setCurrentSessionTemp(_currentUser!.uid);
    }

    final results = <String?>[];
    for (var user in _selectedAccounts) {
      final result = await _signAccountWithNetworkGate(user);
      results.add(result);
    }

    // 统一处理所有签到结果
    for (int i = 0; i < _selectedAccounts.length; i++) {
      final user = _selectedAccounts[i];
      final result = results[i];
      await _handleSignResult(result, user, failedAccounts);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isMultiSigning = false;
      });
    }

    if (mounted) {
      _showMultiSignResult(totalCount, failedAccounts);
    }
  }

  Future<String?> _signAccountWithNetworkGate(User user) async {
    final gateResult = await SignNetworkGate().run<String?>(
      context: context,
      platformLabel: '学习通',
      user: user,
      console: _consoleController,
      action: () => _currentStrategy!.signForAccount(user, _signParams, this),
    );
    if (gateResult.skipped) {
      return '$_networkSkippedResultPrefix${gateResult.reason ?? '用户跳过'}';
    }
    return gateResult.value;
  }

  Future<void> _handleSignResult(
    String? result,
    User user,
    List<String> failedAccounts,
  ) async {
    final recordStore = SignRecordStore();
    if (result == null) {
      failedAccounts.add('${user.name} (无响应)');
      _consoleController.add(
        platform: '学习通',
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.signFailure,
        message: '签到无响应',
      );
      await recordStore.append(
        platform: '学习通',
        platformType: PlatformType.chaoxing,
        courseName: widget.active.name,
        account: user.name,
        status: '失败',
        detail: '无响应',
      );
      return;
    }

    if (result.startsWith(_networkSkippedResultPrefix)) {
      final reason = result.substring(_networkSkippedResultPrefix.length);
      failedAccounts.add('${user.name} ($reason)');
      await recordStore.append(
        platform: '学习通',
        platformType: PlatformType.chaoxing,
        courseName: widget.active.name,
        account: user.name,
        status: '失败',
        detail: reason,
      );
      return;
    }

    if (result.startsWith('validate')) {
      if (result.contains('_')) {
        final parts = result.split('_');
        if (parts.length < 2) {
          failedAccounts.add('${user.name} (验证码格式错误)');
          return;
        }
        final enc2 = parts[1];
        (_userCaptchaValidate[user.uid] ??= {})['enc2'] = enc2;
        if (!await _handleCaptcha(user.uid)) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isMultiSigning = false;
            });
          }
          _showErrorMessage('验证码取消或失败');
          return;
        }
        final resignResult = await _currentStrategy!.signForAccount(
          user,
          _signParams,
          this,
        );
        await _handleSignResult(resignResult, user, failedAccounts);
      }
    } else if (result == 'success') {
      _consoleController.add(
        platform: '学习通',
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.signSuccess,
        message: '签到成功',
      );
      ApiService.appendExternalConsoleLog('学习通', '${user.name} 签到成功');
      await recordStore.append(
        platform: '学习通',
        platformType: PlatformType.chaoxing,
        courseName: widget.active.name,
        account: user.name,
        status: '成功',
      );
    } else if (result == 'success2') {
      failedAccounts.add('${user.name} (已过截止时间)');
      _consoleController.add(
        platform: '学习通',
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.signFailure,
        message: '已过截止时间',
      );
      await recordStore.append(
        platform: '学习通',
        platformType: PlatformType.chaoxing,
        courseName: widget.active.name,
        account: user.name,
        status: '失败',
        detail: '已过截止时间',
      );
    } else {
      failedAccounts.add('${user.name} ($result)');
      _consoleController.add(
        platform: '学习通',
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.signFailure,
        message: result,
      );
      await recordStore.append(
        platform: '学习通',
        platformType: PlatformType.chaoxing,
        courseName: widget.active.name,
        account: user.name,
        status: '失败',
        detail: result,
      );
    }
  }

  Future<bool> _handleCaptcha(String userId) async {
    try {
      final validate = await CaptchaPage.showSlideCaptchaDialog(
        context,
        referer: widget.active.url,
      );

      if (validate != null) {
        (_userCaptchaValidate[userId] ??= {})['validate'] = validate;
        return true;
      } else {
        return false;
      }
    } catch (e) {
      _showErrorMessage('验证码处理失败: $e');
      return false;
    }
  }

  void _showMultiSignResult(int totalCount, List<String> failedAccounts) {
    if (!mounted) return;

    final successCount = totalCount - failedAccounts.length;
    String message = '签到完成！\n成功: $successCount/$totalCount';
    if (failedAccounts.isNotEmpty) {
      message += '\n\n失败账号:\n${failedAccounts.join('\n')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          successCount == totalCount ? '全部签到成功' : '部分失败',
          style: TextStyle(
            color: successCount == totalCount ? Colors.green : Colors.orange,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void performMultiSign() => _performMultiSign();
  void showErrorMessage(String message) => _showErrorMessage(message);
  String getCodeInput() => _codeControllers.map((c) => c.text).join('');
  void checkCodeCompletion() {
    final code = getCodeInput();
    if (code.length == _signParams.numberCount) {
      _signParams.code = code;
    }
  }

  // 多账号签到状态管理
  void updateMultiSignStatus(bool isMultiSigning, [int? totalCount]) {
    if (mounted) {
      setState(() {
        _isMultiSigning = isMultiSigning;
      });
    }
  }

  void showProgressSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void updatePhotoProgress(int completedCount) {
    // 照片上传进度更新（可选实现）
    if (mounted) {
      setState(() {});
    }
  }

  final List<String> _failedAccounts = [];

  void addFailedAccount(String accountInfo) {
    _failedAccounts.add(accountInfo);
  }

  void showPhotoResult(int successCount, int totalCount) {
    if (!mounted) return;

    final failedCount = _failedAccounts.length;
    final message = failedCount == 0
        ? '成功为 $successCount 个账号上传照片'
        : '成功 $successCount 个，失败 $failedCount 个：${_failedAccounts.join(", ")}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );

    _failedAccounts.clear();
  }
}
