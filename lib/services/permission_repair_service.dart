import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification_service.dart';

enum PermissionRepairStatus { granted, denied, permanentlyDenied, unsupported }

class PermissionRepairItem {
  const PermissionRepairItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.canRequest,
  });

  final String id;
  final String title;
  final String description;
  final PermissionRepairStatus status;
  final bool canRequest;

  bool get needsAttention =>
      status == PermissionRepairStatus.denied ||
      status == PermissionRepairStatus.permanentlyDenied;
}

class PermissionRepairService {
  PermissionRepairService({NotificationService? notificationService})
    : _notificationService = notificationService ?? NotificationService();

  final NotificationService _notificationService;

  Future<List<PermissionRepairItem>> inspect() async {
    final notifications = await _notificationService
        .checkPermissionStatus()
        .catchError((_) => false);
    final camera = await Permission.camera.status;
    final location = await Permission.location.status;
    final storage = await Permission.storage.status;
    final connectivity = await Connectivity().checkConnectivity();
    final hasNetwork = connectivity.any(
      (item) => item != ConnectivityResult.none,
    );

    return <PermissionRepairItem>[
      PermissionRepairItem(
        id: 'notification',
        title: '通知权限',
        description: '用于待办提醒、下载失败和健康中心重要提示。',
        status: notifications
            ? PermissionRepairStatus.granted
            : PermissionRepairStatus.denied,
        canRequest: true,
      ),
      _fromPermission(
        id: 'camera',
        title: '相机权限',
        description: '用于扫码签到、课堂码和二维码识别。',
        status: camera,
      ),
      _fromPermission(
        id: 'location',
        title: '定位权限',
        description: '用于需要定位证明的签到场景。',
        status: location,
      ),
      _fromPermission(
        id: 'storage',
        title: '文件访问',
        description: '文件选择器通常可用；如预览或分享失败，可到系统设置检查。',
        status: storage,
      ),
      PermissionRepairItem(
        id: 'network',
        title: '网络状态',
        description: hasNetwork ? '当前设备已有网络连接。' : '当前没有可用网络连接。',
        status: hasNetwork
            ? PermissionRepairStatus.granted
            : PermissionRepairStatus.denied,
        canRequest: false,
      ),
    ];
  }

  Future<void> request(String id) async {
    switch (id) {
      case 'notification':
        await _notificationService.requestPermissions();
      case 'camera':
        await Permission.camera.request();
      case 'location':
        await Permission.location.request();
      case 'storage':
        await Permission.storage.request();
      default:
        break;
    }
  }

  Future<bool> openSettings() {
    return openAppSettings();
  }

  static PermissionRepairItem _fromPermission({
    required String id,
    required String title,
    required String description,
    required PermissionStatus status,
  }) {
    final mapped = status.isGranted || status.isLimited
        ? PermissionRepairStatus.granted
        : status.isPermanentlyDenied
        ? PermissionRepairStatus.permanentlyDenied
        : PermissionRepairStatus.denied;
    return PermissionRepairItem(
      id: id,
      title: title,
      description: description,
      status: mapped,
      canRequest: mapped != PermissionRepairStatus.permanentlyDenied,
    );
  }
}
