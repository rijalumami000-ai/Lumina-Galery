import 'dart:ui';
import 'package:flutter/material.dart';

class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final Color? tintColor;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final double? width;
  final double? height;

  const GlassBox({
    Key? key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = 16.0,
    this.tintColor,
    this.border,
    this.padding,
    this.constraints,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color defaultTint = Colors.white.withOpacity(0.06);
    final Border defaultBorder = Border.all(
      color: Colors.white.withOpacity(0.12),
      width: 1.0,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          constraints: constraints,
          decoration: BoxDecoration(
            color: tintColor ?? defaultTint,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? defaultBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}
