import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.symbol = false, this.height = 40});

  final bool symbol;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
    symbol ? 'assets/images/logo 1.png' : 'assets/images/logo 2.png',
    height: height,
    width: symbol ? height : height * 1209 / 332,
    fit: BoxFit.contain,
    semanticLabel: 'LearnSphere',
  );
}
