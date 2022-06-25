import 'package:flutter/material.dart';
import '../configs/app_store.dart';
import '../configs/constants.dart';
import '../generated/l10n.dart';
import '../widgets/common_widgets.dart';

// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../widgets/setting_tile.dart';
// import '../widgets/language_widget.dart';
import '../widgets/theme_mode_switch.dart';
import '../widgets/theme_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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
            children: <Widget>[
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
                  onChanged: (ThemeMode mode) {
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
