import 'package:flutter/material.dart';
import '../configs/app_store.dart';
import '../generated/l10n.dart';
import '../utils/extensions.dart';

class LanguageWidget extends StatelessWidget {
  const LanguageWidget({super.key, required this.onChanged});

  final Function(Locale) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Locale>(
      value: appStore.selectedLanguage.parseLocale(),
      underline: const SizedBox(),
      onChanged: (Locale? value) async {
        if (value != null) {
          await S.load(value);
          appStore.setLanguage(value.toString());
          onChanged(value);
        }
      },
      selectedItemBuilder: (BuildContext context) {
        return S.delegate.supportedLocales
            .map((Locale e) => DropdownMenuItem<Locale>(
                  value: e,
                  child: SizedBox(
                    width: 80,
                    child: Text(
                      e.countryCode?.toLangIcon() ?? '',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ))
            .toList();
      },
      items: S.delegate.supportedLocales
          .map((Locale e) => DropdownMenuItem<Locale>(
                value: e,
                child: Text(e.countryCode?.toLangName() ?? ''),
              ))
          .toList(),
    );
  }
}
