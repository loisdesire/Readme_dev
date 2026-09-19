// File: lib/widgets/app_dialog.dart
//
// Central, reusable dialog widget. Every popup in the app should go through
// this so they all share the same purple-branded look.
//
// Quick usage:
//   showDialog(
//     context: context,
//     builder: (_) => AppDialog(
//       icon: Icons.timer_off,
//       iconColor: AppTheme.warningOrange,
//       title: 'Outside Reading Hours',
//       message: 'Please try again during your reading hours!',
//       primaryLabel: 'OK',
//       onPrimary: () { Navigator.pop(context); },
//     ),
//   );
//
// For a destructive confirm, use the static helper:
//   final confirmed = await AppDialog.confirm(context, ...);

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppDialog extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? message;
  final Widget? content;
  /// Null means no primary button at all — for a dialog that only needs
  /// a single (secondary) action, e.g. the parental gate's "Cancel" with
  /// the real answers living in [content]. Don't fake this with a blank
  /// label; leave it null and the footer renders just the secondary
  /// button, full-width.
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final Color? primaryColor;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Color? secondaryColor;
  /// Shows a small "X" dismiss button on the icon band. For dialogs that
  /// need a third, non-destructive "just close this" escape hatch
  /// alongside two other footer actions (e.g. filter dialogs with a
  /// "Clear All" that doesn't close the dialog, plus "Apply") — the
  /// primary/secondary footer only ever has room for two.
  final bool showCloseButton;
  final VoidCallback? onClose;

  const AppDialog({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.message,
    this.content,
    this.primaryLabel,
    this.onPrimary,
    this.primaryColor,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryColor,
    this.showCloseButton = false,
    this.onClose,
  });

  // ---------------------------------------------------------------------------
  // Convenience static helpers
  // ---------------------------------------------------------------------------

  static Future<void> show(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    String? message,
    Widget? content,
    String primaryLabel = 'OK',
    VoidCallback? onPrimary,
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppDialog(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        content: content,
        primaryLabel: primaryLabel,
        onPrimary: onPrimary ?? () => Navigator.of(ctx).pop(),
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color? confirmColor,
    bool barrierDismissible = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppDialog(
        icon: icon,
        iconColor: iconColor ?? AppTheme.errorRed,
        title: title,
        message: message,
        primaryLabel: confirmLabel,
        primaryColor: confirmColor ?? AppTheme.errorRed,
        onPrimary: () => Navigator.of(ctx).pop(true),
        secondaryLabel: cancelLabel,
        onSecondary: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AppTheme.primaryPurple;
    final resolvedPrimaryColor = primaryColor ?? AppTheme.primaryPurple;
    final resolvedSecondaryColor = secondaryColor ?? AppTheme.textGray;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- coloured top band with icon ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: resolvedIconColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 42),
                  if (showCloseButton)
                    Positioned(
                      top: 4,
                      right: 8,
                      child: _CloseBtn(
                        onTap: onClose ?? () => Navigator.of(context).pop(),
                      ),
                    ),
                ],
              ),
            ),

            // ---- body ----
            // Wrapped in Flexible so this section is actually bounded to
            // "whatever's left after the icon band and button row claim
            // their space" — a plain (non-Flexible) child here gets asked
            // for its full natural height regardless of how little room
            // is really left, which is what let a content-heavy dialog
            // (e.g. several TextFields) overflow instead of scrolling.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTheme.heading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        message!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textGray,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: 16),
                      // Flexible (not just the caller's own
                      // SingleChildScrollView) so content genuinely gets
                      // a bounded height to scroll within, rather than
                      // being asked for its natural/unbounded size.
                      Flexible(child: content!),
                    ],
                  ],
                ),
              ),
            ),

            // ---- buttons ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: primaryLabel != null && secondaryLabel != null
                  ? Row(
                      children: [
                        Expanded(
                          child: _SecondaryBtn(
                            label: secondaryLabel!,
                            color: resolvedSecondaryColor,
                            onTap: onSecondary ?? () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrimaryBtn(
                            label: primaryLabel!,
                            color: resolvedPrimaryColor,
                            onTap: onPrimary ?? () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: secondaryLabel != null
                          ? _SecondaryBtn(
                              label: secondaryLabel!,
                              color: resolvedSecondaryColor,
                              onTap: onSecondary ?? () => Navigator.of(context).pop(),
                            )
                          : _PrimaryBtn(
                              label: primaryLabel ?? 'OK',
                              color: resolvedPrimaryColor,
                              onTap: onPrimary ?? () => Navigator.of(context).pop(),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private button helpers
// ---------------------------------------------------------------------------

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: AppTheme.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SecondaryBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: AppTheme.body.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
