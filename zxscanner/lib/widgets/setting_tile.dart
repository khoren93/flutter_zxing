import 'package:flutter/material.dart';

class SettingTile extends StatelessWidget {
  const SettingTile(
    this.context, {
    Key? key,
    this.leading,
    this.title,
    this.trailing,
    this.onTap,
  }) : super(key: key);

  final BuildContext context;
  final IconData? leading;
  final String? title;
  final Widget? trailing;
  final Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: leading != null
            ? Icon(
                leading,
                color: Theme.of(context).colorScheme.secondary,
              )
            : null,
        title: Text(title ?? ''),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
