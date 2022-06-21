import 'package:flutter/material.dart';
import 'package:zxscanner/configs/app_store.dart';
import 'package:zxscanner/configs/constants.dart';
import 'package:zxscanner/generated/l10n.dart';
import 'package:zxscanner/widgets/common_widgets.dart';

// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/setting_tile.dart';
// import '../widgets/language_widget.dart';
import '../widgets/theme_mode_switch.dart';
import '../widgets/theme_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.settingsAppBarTitle),
      ),
      body: SingleChildScrollView(
        child: ContainerX(
          child: Column(
            children: [
              const SizedBox(height: spaceDefault),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: spaceDefault),
                child: ThemeSelector(),
              ),
              SettingTile(
                context,
                leading: Icons.brightness_4,
                title: S.current.settingsThemeModeTitle,
                trailing: ThemeModeSwitch(
                  themeMode: appStore.themeMode,
                  onChanged: (mode) {
                    appStore.setThemeMode(mode);
                    setState(() {});
                  },
                ),
              ),
              // SettingTile(
              //   context,
              //   leading: FontAwesomeIcons.globe,
              //   title: S.current.settingsLanguageTitle,
              //   trailing: LanguageWidget(
              //     onChanged: (value) {
              //       setState(() {});
              //     },
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
