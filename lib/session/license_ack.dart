import 'package:flutter/foundation.dart';

bool _customLicenseRegistered = false;

void registerCustomAcknowledgementLicenses() {
  if (_customLicenseRegistered) {
    return;
  }
  _customLicenseRegistered = true;

  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['学习通/雨课堂平台参考源码'],
      '致谢项目\n'
      '学习通/雨课堂平台感谢 https://github.com/AneryCoft 的源码。\n\n'
      '说明\n'
      '该条目用于记录源码参考来源，请同时遵循对应仓库发布的 LICENSE 条款。',
    );
  });

  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['畅课平台参考源码'],
      '致谢项目\n'
      '畅课平台感谢 https://github.com/wilinz/tronclass_plus 源码。\n\n'
      '畅课平台登录美化接口感谢 https://github.com/chongzi/guethub 源码。\n\n'
      '说明\n'
      '该条目用于记录源码参考来源，请同时遵循对应仓库发布的 LICENSE 条款。',
    );
  });

  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['课堂派平台参考源码'],
      '致谢项目\n'
      '课堂派平台感谢 https://github.com/roselle-luo/fuckketangpai_app 源码。\n\n'
      '说明\n'
      '该条目用于记录源码参考来源，请同时遵循对应仓库发布的 LICENSE 条款。',
    );
  });

  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      <String>['微助教平台参考源码'],
      '致谢项目\n'
      '微助教平台感谢 https://github.com/zn-cn/wzj-sign-in-weixin 源码。\n\n'
      '说明\n'
      '该条目用于记录源码参考来源，请同时遵循对应仓库发布的 LICENSE 条款。',
    );
  });
}
