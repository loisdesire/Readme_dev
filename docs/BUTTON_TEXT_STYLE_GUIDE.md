# 🎨 Button Text Style Guide

## Quick Reference for Button Text Styling

### Available Styles (Updated November 18, 2025)

```dart
// Standard button text (white color, medium weight)
Text('Click Me', style: AppTheme.buttonText)

// Explicit style for colored backgrounds (same as buttonText, clearer intent)
Text('Submit', style: AppTheme.buttonTextOnColor)

// Large button text for prominent CTAs
Text('Get Started', style: AppTheme.buttonTextLarge)
```

---

## When to Use Which Style

### ✅ DO Use `AppTheme.buttonText` or `AppTheme.buttonTextOnColor`

**For all ElevatedButtons with colored backgrounds:**
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppTheme.primaryPurple,
  ),
  onPressed: () {},
  child: Text('Start Reading', style: AppTheme.buttonText),
)
```

**For prominent call-to-action buttons:**
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('Get Started', style: AppTheme.buttonTextLarge),
)
```

---

### ❌ DON'T Use `AppTheme.heading` on Buttons

**Wrong:**
```dart
Text('Button Text', style: AppTheme.heading.copyWith(color: Colors.white))
```

**Why?** 
- `AppTheme.heading` has black color by default
- Requires manual color override (easy to forget)
- Less semantic (heading ≠ button)

**Right:**
```dart
Text('Button Text', style: AppTheme.buttonText)
```

---

## Style Specifications

### AppTheme.buttonText
- **Font**: DM Sans
- **Size**: 16px
- **Weight**: 500 (Medium)
- **Color**: White (#FFFFFF)
- **Use**: Standard buttons

### AppTheme.buttonTextOnColor
- **Alias for**: `buttonText`
- **Purpose**: Makes intent explicit when used on colored backgrounds
- **Use**: When you want to emphasize "this text is on a colored button"

### AppTheme.buttonTextLarge
- **Font**: DM Sans
- **Size**: 18px
- **Weight**: 600 (Semibold)
- **Color**: White (#FFFFFF)
- **Use**: Large CTA buttons, hero actions

---

## Examples from Codebase

### Good Examples ✅

**Quiz Screen:**
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8E44AD)),
  child: Text('Next', style: AppTheme.buttonText.copyWith(fontWeight: FontWeight.w600)),
)
```

**Onboarding Screen:**
```dart
ElevatedButton(
  child: Text('Get started', style: AppTheme.buttonText),
)
```

**Profile Edit:**
```dart
ElevatedButton(
  child: Text('Save Changes', style: AppTheme.buttonText),
)
```

---

## Migration Notes

**Previously Fixed Issues:**
- Quiz result screen button text (November 18, 2025)
  - Changed from: `AppTheme.heading.copyWith(fontWeight: FontWeight.w600)`
  - Changed to: `AppTheme.heading.copyWith(fontWeight: FontWeight.w600, color: Colors.white)`
  - Better alternative: `AppTheme.buttonTextLarge`

---

## Customization

If you need a specific variation, extend from `buttonText`:

```dart
// Custom button text with different size
Text(
  'Custom Button',
  style: AppTheme.buttonText.copyWith(fontSize: 14),
)

// Custom button text with different weight
Text(
  'Bold Button',
  style: AppTheme.buttonText.copyWith(fontWeight: FontWeight.w700),
)

// Custom button text with icon color matching
Row(
  children: [
    Icon(Icons.check, color: Colors.white),
    Text('Confirm', style: AppTheme.buttonText),
  ],
)
```

---

## Related Styles

**For text buttons (no background):**
```dart
TextButton(
  child: Text('Cancel', style: AppTheme.body.copyWith(color: AppTheme.primaryPurple)),
)
```

**For link-style buttons:**
```dart
TextButton(
  child: Text('Learn More', style: AppTheme.bodyMedium.copyWith(
    color: AppTheme.primaryPurple,
    decoration: TextDecoration.underline,
  )),
)
```

---

## Summary

✅ **Use**: `AppTheme.buttonText` for all button text on colored backgrounds  
✅ **Use**: `AppTheme.buttonTextLarge` for prominent CTA buttons  
✅ **Use**: `AppTheme.buttonTextOnColor` when you want explicit clarity  
❌ **Avoid**: `AppTheme.heading` on buttons (semantic mismatch + requires color override)
