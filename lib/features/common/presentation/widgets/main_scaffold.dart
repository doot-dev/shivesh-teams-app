import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Floating bottom navigation shell.
///
/// The selected tab animates a filled blue "pill" behind its icon rather than
/// just recolouring it — the pill is the only moving part, which keeps the bar
/// calm while still reading as responsive.
class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  static const _destinations = [
    _NavDest('/home', Icons.grid_view_rounded, Icons.grid_view_outlined, 'Home'),
    _NavDest('/orders', Icons.local_shipping_rounded,
        Icons.local_shipping_outlined, 'Orders'),
    _NavDest('/profile', Icons.person_rounded, Icons.person_outline_rounded,
        'Profile'),
  ];

  int _locationToIndex(String loc) {
    if (loc.startsWith('/orders')) return 1;
    if (loc.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _locationToIndex(location);

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.shadowLg,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: List.generate(_destinations.length, (index) {
                final dest = _destinations[index];
                final isSelected = index == selectedIndex;
                return Expanded(
                  child: _NavItem(
                    dest: dest,
                    selected: isSelected,
                    onTap: () {
                      if (dest.path != location) context.go(dest.path);
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  final _NavDest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      splashColor: AppColors.blue50,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: AppMotion.mid,
        curve: AppMotion.ease,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The pill: width animates open only for the selected tab.
            AnimatedContainer(
              duration: AppMotion.mid,
              curve: AppMotion.ease,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? AppSpacing.lg : AppSpacing.md,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Icon(
                  selected ? dest.activeIcon : dest.icon,
                  key: ValueKey(selected),
                  size: 21,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppMotion.mid,
              curve: AppMotion.ease,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? AppColors.primary : AppColors.textMuted,
                  ),
              child: Text(dest.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDest {
  const _NavDest(this.path, this.activeIcon, this.icon, this.label);
  final String path;
  final IconData activeIcon;
  final IconData icon;
  final String label;
}
