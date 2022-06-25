import 'package:flutter/material.dart';

extension LocaleParsing on String {
  Locale parseLocale() {
    assert(contains('_') == true);
    final String languageCode = split('_').first;
    final String countryCode = split('_').last;
    return Locale.fromSubtags(
        languageCode: languageCode, countryCode: countryCode);
  }

  String toLangIcon() {
    assert(length == 2);
    switch (toLowerCase()) {
      case 'us':
      case 'en':
        return '🇺🇸';
      case 'ru':
        return '🇷🇺';
      case 'am':
      case 'hy':
        return '🇦🇲';
      default:
        return '🇺🇸';
    }
  }

  String toLangName() {
    assert(length == 2);
    switch (toLowerCase()) {
      case 'us':
      case 'en':
        return '${toLangIcon()} English';
      case 'ru':
        return '${toLangIcon()} Русский';
      case 'am':
      case 'hy':
        return '${toLangIcon()} Հայերեն';
      default:
        return '${toLangIcon()} English';
    }
  }

  String toLangCode() {
    assert(contains('_') == true);
    return split('_').first;
  }
}

// context extension to show a toast message
extension ContextExtension on BuildContext {
  void showToast(String message) {
    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Padding(
          padding: const EdgeInsets.only(bottom: 30.0),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
