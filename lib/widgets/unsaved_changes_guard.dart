import 'package:flutter/material.dart';

/// Protects editable pages from losing input on both toolbar and system back.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.onSave,
    required this.child,
    this.isBusy = false,
  });
  final bool hasChanges;
  final bool isBusy;
  final Future<bool> Function() onSave;
  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => _UnsavedChangesGuardState();
}

class _UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _allowPop = false;
  bool _handlingBack = false;

  Future<void> _handleBack(Object? result) async {
    if (_handlingBack) return;
    final en = Localizations.localeOf(context).languageCode == 'en';
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusScope.of(context).unfocus();
      return;
    }
    if (widget.isBusy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            en
                ? 'Please wait for the current operation to finish.'
                : '正在保存或提交，请稍候。',
          ),
        ),
      );
      return;
    }
    _handlingBack = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(en ? 'Unsaved changes' : '还有未保存的内容'),
          content: Text(
            en ? 'Save your changes before leaving?' : '是否保存后再离开？保存失败会保留当前输入。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(en ? 'Keep editing' : '继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: Text(en ? 'Discard and leave' : '放弃并离开'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text(en ? 'Save and leave' : '保存并离开'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'save') {
        bool saved;
        try {
          saved = await widget.onSave();
        } catch (_) {
          saved = false;
        }
        if (!mounted) return;
        if (!saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                en
                    ? 'Could not save. Your input is still here.'
                    : '保存未成功，已保留当前输入。',
              ),
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(result);
      });
    } finally {
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _allowPop || (!widget.hasChanges && !widget.isBusy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _handleBack(result);
    },
    child: widget.child,
  );
}
