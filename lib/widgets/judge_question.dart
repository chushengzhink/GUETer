// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// 判断题组件
class JudgeQuestion extends StatelessWidget {
  final String question;
  final bool? selectedAnswer;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const JudgeQuestion({
    super.key,
    required this.question,
    required this.selectedAnswer,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            question,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        InkWell(
          onTap: enabled ? () => onChanged(true) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: selectedAnswer,
                  onChanged: enabled ? (value) => onChanged(value!) : null,
                ),
                const SizedBox(width: 8),
                const Text('正确', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: enabled ? () => onChanged(false) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Radio<bool>(
                  value: false,
                  groupValue: selectedAnswer,
                  onChanged: enabled ? (value) => onChanged(value!) : null,
                ),
                const SizedBox(width: 8),
                const Text('错误', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
