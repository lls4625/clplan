import 'package:flutter/cupertino.dart';

import '../l10n/ui_text.dart' show localizeUiText;

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
      title: Text(localizeUiText(dialogContext, title)),
      content: Text(localizeUiText(dialogContext, message)),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(localizeUiText(dialogContext, dismissLabel)),
        ),
        if (actionLabel != null && onAction != null)
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onAction();
            },
            child: Text(localizeUiText(dialogContext, actionLabel)),
          ),
      ],
    ),
  );
}
