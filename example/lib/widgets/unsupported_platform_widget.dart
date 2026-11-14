// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

class UnsupportedPlatformWidget extends StatelessWidget {
  const UnsupportedPlatformWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This platform is not supported yet.',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
