import 'package:flutter/material.dart';

class UnsupportedPlatformWidget extends StatelessWidget {
  const UnsupportedPlatformWidget({Key? key}) : super(key: key);

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
