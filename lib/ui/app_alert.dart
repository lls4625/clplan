import 'package:flutter/cupertino.dart';

void showAppAlert(
  BuildContext context, {
  required String title,
  required String message,
  String dismissLabel = '知道了',
  String? actionLabel,
  VoidCallback? onAction,
}) {
  if (!context.mounted) return;
  showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dismissLabel),
        ),
        if (actionLabel != null && onAction != null)
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onAction();
            },
            child: Text(actionLabel),
          ),
      ],
    ),
  );
}
