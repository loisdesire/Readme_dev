import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.assetPath = 'assets/branding/logo_purple_transparent.png',
    this.size = 72,
    this.showWordmark = false,
    this.wordmark = 'ReadMe',
    this.wordmarkSpacing = 8,
    this.preferAssetOnWeb = false,
    this.fallbackAssetPath = 'web/icons/Icon-512.png',
  });

  final String assetPath;
  final double size;
  final bool showWordmark;
  final String wordmark;
  final double wordmarkSpacing;
  final bool preferAssetOnWeb;
  final String fallbackAssetPath;

  static const String _embeddedLogoSvg =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">'
      '<defs>'
      '<linearGradient id="g" x1="32" y1="32" x2="224" y2="224" gradientUnits="userSpaceOnUse">'
      '<stop stop-color="#8E44AD"/>'
      '<stop offset="1" stop-color="#A062BA"/>'
      '</linearGradient>'
      '</defs>'
      '<rect x="24" y="24" width="208" height="208" rx="48" fill="url(#g)"/>'
      '<rect x="64" y="76" width="128" height="112" rx="18" fill="#FFFFFF" fill-opacity="0.95"/>'
      '<path d="M88 88C101 82 114 82 128 88C142 82 155 82 168 88V180C155 174 142 174 128 180C114 174 101 174 88 180V88Z" fill="#8E44AD" fill-opacity="0.16"/>'
      '<path d="M128 92V176" stroke="#8E44AD" stroke-opacity="0.22" stroke-width="6" stroke-linecap="round"/>'
      '<circle cx="92" cy="132" r="6" fill="#8E44AD" fill-opacity="0.55"/>'
      '<circle cx="164" cy="132" r="6" fill="#8E44AD" fill-opacity="0.55"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    final lower = assetPath.toLowerCase();
    final isSvg = lower.endsWith('.svg');

    Widget mark;

    if (isSvg) {
      if (kIsWeb && !preferAssetOnWeb) {
        mark = SvgPicture.string(
          _embeddedLogoSvg,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        mark = SvgPicture.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      }
    } else {
      mark = Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, _, __) {
          return Image.asset(
            fallbackAssetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, _, __) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.20),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppTheme.primaryPurple,
                    size: 36,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    if (!showWordmark) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: wordmarkSpacing),
        Text(
          wordmark,
          style: AppTheme.logoLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
