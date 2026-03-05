import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum NavItem { home, explore, cart, profile }

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.current,
    required this.onTap,
  });

  final NavItem current;
  final ValueChanged<NavItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavIcon(
              icon: Icons.directions_bike_rounded,
              isSelected: current == NavItem.home,
              onTap: () => onTap(NavItem.home),
            ),
            _NavIcon(
              icon: Icons.explore_rounded,
              isSelected: current == NavItem.explore,
              onTap: () => onTap(NavItem.explore),
            ),
            _NavIcon(
              icon: Icons.shopping_cart_rounded,
              isSelected: current == NavItem.cart,
              onTap: () => onTap(NavItem.cart),
            ),
            _NavIcon(
              icon: Icons.person_rounded,
              isSelected: current == NavItem.profile,
              onTap: () => onTap(NavItem.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: isSelected
              ? BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Icon(
            icon,
            size: 24,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.darkText,
          ),
        ),
      ),
    );
  }
}
