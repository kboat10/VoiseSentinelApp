import 'package:flutter/material.dart';

class ThemedScaffold extends StatelessWidget {
  const ThemedScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.padding,
    this.drawer,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final EdgeInsets? padding;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: appBar,
      drawer: drawer,
      body: SafeArea(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(24),
          child: body,
        ),
      ),
    );
  }
}
