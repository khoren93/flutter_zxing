import 'dart:ui';

extension LocaleParsing on String {
  Locale parseLocale() {
    assert(contains('_') == true);
    var languageCode = split('_').first;
    var countryCode = split('_').last;
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
        return toLangIcon() + ' English';
      case 'ru':
        return toLangIcon() + ' Русский';
      case 'am':
      case 'hy':
        return toLangIcon() + ' Հայերեն';
      default:
        return toLangIcon() + ' English';
    }
  }

  String toLangCode() {
    assert(contains('_') == true);
    return split('_').first;
  }
}
