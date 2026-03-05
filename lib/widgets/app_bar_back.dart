import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBarBack extends StatelessWidget implements PreferredSizeWidget {
  const AppBarBack({
    super.key,
    required this.title,
    this.onBack,
  });

  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        color: isDark ? AppTheme.darkTextLight : AppTheme.darkText,
      ),
      title: Text(
        title,
        style: theme.appBarTheme.titleTextStyle,
      ),
    );
  }
}
