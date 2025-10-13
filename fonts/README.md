# Font Installation Instructions

To fix the emoji display issues, you need to download and install the Noto Color Emoji font.

## Steps:
1. Download NotoColorEmoji.ttf from Google Fonts or the official Noto repository:
   - Visit: https://fonts.google.com/noto/specimen/Noto+Color+Emoji
   - Or download directly from: https://github.com/googlefonts/noto-emoji/releases

2. Place the downloaded NotoColorEmoji.ttf file in the fonts/ directory

3. Run `flutter clean && flutter pub get` to refresh the app

## Alternative (Quick Fix):
If you can't download the font immediately, the app will fall back to system emoji fonts:
- Windows: Segoe UI Emoji
- macOS/iOS: Apple Color Emoji  
- Android: Noto Color Emoji (built-in)

The fontFamilyFallback configuration in AppTheme will handle this automatically.