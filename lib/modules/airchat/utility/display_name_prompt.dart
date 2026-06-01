import 'package:flutter/material.dart';

import '../services/airchat_storage_service.dart';

Future<void> showDisplayNamePrompt(BuildContext context) async {
  final storage = AirChatStorageService.instance;
  final displayName = storage.displayName.trim();
  if (displayName.isNotEmpty && displayName != 'AirChatUser') {
    return;
  }

  final nameController = TextEditingController(
    text: displayName == 'AirChatUser' ? '' : displayName,
  );
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Nearby Room Name',
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.88,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        colorScheme.primary.withValues(alpha: 0.85),
                        colorScheme.secondary.withValues(alpha: 0.85),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '设置附近房间名称',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '该名称会用于附近房间发现、连接和本机房间广播展示。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    hintText: '输入名称',
                    prefixIcon: const Icon(Icons.edit_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  onSubmitted: (_) => _saveDisplayName(nameController, dialogContext),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveDisplayName(nameController, dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('继续'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (
      BuildContext transitionContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
          child: child,
        ),
      );
    },
  );
  nameController.dispose();
}

Future<void> _saveDisplayName(
  TextEditingController controller,
  BuildContext context,
) async {
  final name = controller.text.trim();
  if (name.isEmpty) {
    return;
  }
  await AirChatStorageService.instance.setDisplayName(name);
  if (context.mounted) {
    Navigator.of(context).pop();
  }
}
