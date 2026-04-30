import 'package:flutter/material.dart';
import 'package:pattern_lock/pattern_lock.dart';

import '../../../../models/user.dart';
import '../../../../session/account.dart';
import '../../../../api/chaoxing_sign_api.dart';
import 'sign_in.dart';

class PatternSign implements SignStrategy {
  @override
  Future<void> execute(
      BuildContext context,
      SignInPageState state,
      SignParams params,
      ) async {
  }

  @override
  Future<String?> signForAccount(User user, SignParams params, SignInPageState state) async {
    final userValidate = state.getUserCaptchaValidate(user.uid);
    final validate = userValidate?['validate'];

    try {
      AccountManager.setCurrentSessionTemp(user.uid);

      final response = await ChaoxingSignApi.signCode(
        activeId: params.active.id,
        courseId: params.courseId,
        uid: user.uid,
        name: user.name,
        signCode: params.pattern,
        validate: validate,
      );

      return response.data?.toString();
    } catch (e) {
      return null;
    }
  }

  static Widget buildSignArea(SignInPageState state) {
    return Builder(
      builder: (BuildContext context) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PatternLock(
                    dimension: 3,
                    relativePadding: 0.5,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    notSelectedColor: Theme.of(context).dividerColor,
                    pointRadius: 30,
                    onInputComplete: (List<int> pattern) async {
                      final pattern1to9 = pattern.map((p) => p + 1).toList().join('');
                      state.signParams.pattern = pattern1to9;

                      bool isValid = await ChaoxingSignApi.checkSignCode(
                        activeId: state.widget.active.id,
                        signCode: pattern1to9,
                      );

                      if (isValid) {
                        state.performMultiSign();
                      } else {
                        state.showErrorMessage('手势不正确，请重新绘制');
                        state.signParams.pattern = '';
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}