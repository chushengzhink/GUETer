// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'package:flutter/material.dart';

Future<String?> showDeviceNameDialog(
  BuildContext context, {
  required String initialValue,
  required bool allowCancel,
}) async {
  final controller = TextEditingController(text: initialValue);
  String? errorText;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (BuildContext dialogContext) {
      return PopScope(
        canPop: allowCancel,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(allowCancel ? '设置本机名称' : '首次设置本机名称'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      allowCancel ? '其他设备会优先看到这个名称。' : '局域网快传需要先设置一个易于识别的设备名称。',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 32,
                      decoration: InputDecoration(
                        labelText: '设备名称',
                        hintText: '例如：小米平板 / 宿舍电脑 / 我的手机',
                        errorText: errorText,
                      ),
                      onSubmitted: (_) {
                        final trimmed = controller.text.trim();
                        if (trimmed.isEmpty) {
                          setState(() {
                            errorText = '请输入设备名称';
                          });
                          return;
                        }
                        Navigator.of(dialogContext).pop(trimmed);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                if (allowCancel)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消'),
                  ),
                FilledButton(
                  onPressed: () {
                    final trimmed = controller.text.trim();
                    if (trimmed.isEmpty) {
                      setState(() {
                        errorText = '请输入设备名称';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(trimmed);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  controller.dispose();
  return result;
}
