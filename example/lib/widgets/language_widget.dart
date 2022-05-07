import 'package:flutter/material.dart';
import 'package:flutter_zxing_example/configs/app_store.dart';
import 'package:flutter_zxing_example/generated/l10n.dart';
import 'package:flutter_zxing_example/utils/extensions.dart';

class LanguageWidget extends StatelessWidget {
  const LanguageWidget({Key? key, required this.onChanged}) : super(key: key);

  final Function(Locale) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Locale>(
      value: appStore.selectedLanguage.parseLocale(),
      isExpanded: false,
      isDense: false,
      underline: const SizedBox(),
      onChanged: (value) async {
        if (value != null) {
          await S.load(value);
          appStore.setLanguage(value.toString());
          onChanged(value);
        }
      },
      selectedItemBuilder: (context) {
        return S.delegate.supportedLocales
            .map((e) => DropdownMenuItem<Locale>(
                  value: e,
                  child: SizedBox(
                    width: 80,
                    child: Text(
                      e.countryCode?.toLangIcon() ?? '',
                      style: Theme.of(context).textTheme.headline5,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ))
            .toList();
      },
      items: S.delegate.supportedLocales
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.countryCode?.toLangName() ?? ''),
              ))
          .toList(),
    );
  }
}
