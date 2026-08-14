import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Confirmation and feedback helpers so every destructive action looks alike.
class AppDialogs {
  const AppDialogs._();

  /// Returns true only when the user explicitly confirms.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    )
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

/// Snackbar helpers. Success is neutral-dark, failure uses the error colour.
extension AppMessenger on BuildContext {
  void showSuccess(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Colors.white,
              ),
              AppSpacing.wGapSm,
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  void showFailure(String message) {
    final scheme = Theme.of(this).colorScheme;
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: scheme.error,
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: Colors.white,
              ),
              AppSpacing.wGapSm,
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
