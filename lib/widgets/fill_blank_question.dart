import 'package:flutter/material.dart';

/// 填空题组件
class FillBlankQuestion extends StatefulWidget {
  final String question;
  final List<String> answers;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  const FillBlankQuestion({
    super.key,
    required this.question,
    required this.answers,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<FillBlankQuestion> createState() => _FillBlankQuestionState();
}

class _FillBlankQuestionState extends State<FillBlankQuestion> {
  late List<TextEditingController> _controllers;
  int _blankCount = 0;

  @override
  void initState() {
    super.initState();
    _blankCount = _countBlanks(widget.question);
    _controllers = List.generate(
      _blankCount,
      (index) => TextEditingController(
        text: index < widget.answers.length ? widget.answers[index] : '',
      ),
    );

    for (var controller in _controllers) {
      controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  int _countBlanks(String text) {
    final regex = RegExp(r'_{2,}');
    return regex.allMatches(text).length;
  }

  void _onTextChanged() {
    final answers = _controllers.map((c) => c.text).toList();
    widget.onChanged(answers);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildQuestionWithBlanks(),
        ),
      ],
    );
  }

  Widget _buildQuestionWithBlanks() {
    final parts = widget.question.split(RegExp(r'_{2,}'));
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        widgets.add(
          Text(
            parts[i],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      if (i < _controllers.length) {
        widgets.add(
          Container(
            width: 150,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _controllers[i],
              enabled: widget.enabled,
              decoration: InputDecoration(
                hintText: '填空${i + 1}',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}
