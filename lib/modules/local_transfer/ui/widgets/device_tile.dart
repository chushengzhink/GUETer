// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'package:flutter/material.dart';

import '../../model/transfer_device.dart';
import '../../theme/local_transfer_theme.dart';

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final TransferDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = LocalTransferThemeData.resolve(context);
    final theme = Theme.of(context);
    final deviceModel = device.deviceModel?.trim() ?? '';
    final showModel =
        deviceModel.isNotEmpty && deviceModel != device.displayName;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? palette.surfaceTint.withValues(alpha: 0.65)
              : palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? palette.primary
                : palette.outline.withValues(alpha: 0.3),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForType(device.deviceType),
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    device.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showModel)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        deviceModel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${device.ip}:${device.port} · ${device.protocol.toUpperCase()} · ${device.discoveryMethod}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: palette.primary)
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

IconData _iconForType(String? type) {
  switch (type) {
    case 'desktop':
      return Icons.desktop_windows_rounded;
    case 'web':
      return Icons.language_rounded;
    case 'server':
      return Icons.dns_rounded;
    default:
      return Icons.phone_android_rounded;
  }
}
