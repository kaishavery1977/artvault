import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension CtxX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colors => theme.colorScheme;
  double get w => MediaQuery.sizeOf(this).width;
  double get h => MediaQuery.sizeOf(this).height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
  bool get isDark => theme.brightness == Brightness.dark;
  void push(String r, {Object? extra}) =>
      GoRouter.of(this).push(r, extra: extra);
  void go(String r, {Object? extra}) => GoRouter.of(this).go(r, extra: extra);
}
