import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session/ketangpai_semester.dart';
import 'account_context_header.dart';

Future<KetangpaiSemester?> showKetangpaiSemesterPicker(
  BuildContext context,
  KetangpaiSemester selected,
) => showModalBottomSheet<KetangpaiSemester>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => KetangpaiSemesterPicker(selected: selected),
);

class KetangpaiSemesterPicker extends StatefulWidget {
  const KetangpaiSemesterPicker({super.key, required this.selected});
  final KetangpaiSemester selected;

  @override
  State<KetangpaiSemesterPicker> createState() =>
      _KetangpaiSemesterPickerState();
}

class _KetangpaiSemesterPickerState extends State<KetangpaiSemesterPicker> {
  final _formKey = GlobalKey<FormState>();
  late final _year = TextEditingController(
    text: '${widget.selected.startYear}',
  );
  late int _term = widget.selected.term;

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _apply() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, KetangpaiSemester(int.parse(_year.text), _term));
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = int.tryParse(_year.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contextText(context, '切换学期', 'Change semester'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('semester-year'),
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: contextText(
                      context,
                      '学年起始年份',
                      'Academic year starts in',
                    ),
                    helperText: year != null && year >= 1000 && year <= 9998
                        ? '$year–${year + 1}'
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (text) {
                    final value = int.tryParse(text ?? '');
                    return value == null || value < 1000 || value > 9998
                        ? contextText(
                            context,
                            '请输入有效的四位年份',
                            'Enter a valid four-digit year',
                          )
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    for (final term in [1, 2])
                      ChoiceChip(
                        label: Text(
                          contextText(
                            context,
                            term == 1 ? '第一学期' : '第二学期',
                            'Semester $term',
                          ),
                        ),
                        selected: _term == term,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: (_) => setState(() => _term = term),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('semester-apply'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _apply,
                  child: Text(
                    contextText(context, '应用并刷新', 'Apply and refresh'),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.pop(context),
                  child: Text(contextText(context, '取消', 'Cancel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
