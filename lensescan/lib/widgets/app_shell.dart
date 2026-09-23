/// App shell — bottom navigation scaffold wrapping tabbed screens.
///
/// Provides a frosted-glass bottom nav bar with Home, Scan, History, Profile.
/// Matches Stitch design: raised teal Scan button, blur backdrop.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';

/// Bottom navigation shell that wraps all main tab screens.
class AppShell extends StatelessWidget {
  final Widget child;
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.child,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: LenseScanTheme.surface.withValues(alpha: 0.9),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                offset: const Offset(0, -4),
                blurRadius: 16,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context,
                    index: 0,
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                  ),
                  _buildScanButton(
                    context,
                    isSelected: currentIndex == 1,
                  ),
                  _buildNavItem(
                    context,
                    index: 2,
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history,
                    label: 'History',
                    isSelected: currentIndex == 2,
                  ),
                  _buildNavItem(
                    context,
                    index: 3,
                    icon: Icons.badge_outlined,
                    selectedIcon: Icons.badge,
                    label: 'Profile',
                    isSelected: currentIndex == 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => navigationShell.goBranch(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 24,
              color: isSelected
                  ? LenseScanTheme.primary
                  : LenseScanTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.33,
                color: isSelected
                    ? LenseScanTheme.primary
                    : LenseScanTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(BuildContext context, {required bool isSelected}) {
    return GestureDetector(
      onTap: () => navigationShell.goBranch(1),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? LenseScanTheme.primaryContainer
                    : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF134E4A).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isSelected
                    ? Icons.qr_code_scanner_rounded
                    : Icons.qr_code_scanner_outlined,
                size: 24,
                color: isSelected
                    ? LenseScanTheme.onPrimary
                    : LenseScanTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Scan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.33,
                color: isSelected
                    ? LenseScanTheme.primary
                    : LenseScanTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
