import 'package:flutter/material.dart';

class ContextHelpHint extends StatelessWidget {
  const ContextHelpHint({
    super.key,
    required this.title,
    required this.tips,
    this.actions = const <Widget>[],
    this.iconOnly = false,
  });

  final String title;
  final List<String> tips;
  final List<Widget> actions;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Tooltip(
        message: title,
        child: Semantics(
          button: true,
          label: title,
          child: IconButton(
            onPressed: () => showContextHelpSheet(
              context,
              title: title,
              tips: tips,
              actions: actions,
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => showContextHelpSheet(
          context,
          title: title,
          tips: tips,
          actions: actions,
        ),
        icon: const Icon(Icons.help_outline_rounded, size: 18),
        label: Text(title),
      ),
    );
  }
}

Future<void> showContextHelpSheet(
  BuildContext context, {
  required String title,
  required List<String> tips,
  List<Widget> actions = const <Widget>[],
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final tip in tips.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline, size: 17),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip)),
                    ],
                  ),
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      );
    },
  );
}
