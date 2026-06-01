import 'package:flutter/material.dart';

/// 多选题组件
class MultiSelectQuestion extends StatefulWidget {
  final String question;
  final List<String> options;
  final List<String> selectedAnswers;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  const MultiSelectQuestion({
    super.key,
    required this.question,
    required this.options,
    required this.selectedAnswers,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<MultiSelectQuestion> createState() => _MultiSelectQuestionState();
}

class _MultiSelectQuestionState extends State<MultiSelectQuestion> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedAnswers);
  }

  @override
  void didUpdateWidget(MultiSelectQuestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedAnswers != oldWidget.selectedAnswers) {
      _selected = List.from(widget.selectedAnswers);
    }
  }

  void _toggleOption(String option) {
    if (!widget.enabled) return;

    setState(() {
      if (_selected.contains(option)) {
        _selected.remove(option);
      } else {
        _selected.add(option);
      }
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            widget.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...widget.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final optionLabel = String.fromCharCode(65 + index); // A, B, C, D...
          final isSelected = _selected.contains(option);

          return CheckboxListTile(
            title: Text('$optionLabel. $option'),
            value: isSelected,
            onChanged: widget.enabled
                ? (value) => _toggleOption(option)
                : null,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
  }
}
