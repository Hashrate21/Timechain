import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const kUndoSnackDuration = Duration(seconds: 4);

void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final colors = AppColors.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();

  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: kUndoSnackDuration,
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.down,
      action: SnackBarAction(
        label: 'Undo',
        textColor: colors.cyan,
        onPressed: onUndo,
      ),
    ),
  );

  // Force auto-dismiss (action snackbars can stick on desktop)
  Future<void>.delayed(kUndoSnackDuration, () {
    messenger.hideCurrentSnackBar();
  });
}