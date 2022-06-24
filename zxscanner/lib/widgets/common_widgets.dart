import 'package:flutter/material.dart';
import '../configs/constants.dart';

class ContainerX extends StatelessWidget {
  const ContainerX({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: spaceMaxWidth),
        child: child,
      ),
    );
  }
}
