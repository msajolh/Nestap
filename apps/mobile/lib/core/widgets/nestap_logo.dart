import 'package:flutter/material.dart';

/// The Nestap wordmark (transparent PNG, brand cyan; works on light and dark).
class NestapLogo extends StatelessWidget {
  const NestapLogo({this.height = 40, super.key});

  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/nestap_logo.png',
        height: height,
        fit: BoxFit.contain,
        semanticLabel: 'Nestap',
      );
}
