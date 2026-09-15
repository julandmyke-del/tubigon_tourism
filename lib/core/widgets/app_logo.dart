import 'package:flutter/material.dart';

import '../constants/asset_paths.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 40,
    this.radius = 12,
  });

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Tour Tubigon logo',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.asset(
            AssetPaths.logo,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
}
