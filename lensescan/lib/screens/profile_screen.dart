/// Profile screen — officer info, stats, settings, and sign-out.
///
/// Matches Stitch design export: 7._officer_profile_screen/code.html
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../core/auth/auth_provider.dart';

/// Officer profile screen with stats, settings list, and sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LenseScanTheme.surface,
      appBar: AppBar(
        backgroundColor: LenseScanTheme.surface.withValues(alpha: 0.9),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: LenseScanTheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 20,
                color: LenseScanTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LegalLens AI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: LenseScanTheme.primary,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Officer Profile',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: LenseScanTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: LenseScanTheme.surfaceContainerHigh,
              child: const Icon(
                Icons.person,
                size: 18,
                color: LenseScanTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // ── Active Duty & HQ Encrypted Bar ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: LenseScanTheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ACTIVE DUTY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: LenseScanTheme.secondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: LenseScanTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Text(
                    'HQ Encrypted',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: LenseScanTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Officer Header Hero Card ──
            _buildProfileHeroCard(context),
            const SizedBox(height: 16),

            // ── Quick Telemetry & Field Stats Strip ──
            _buildStatsRow(context),
            const SizedBox(height: 20),

            // ── System & Field Config Section Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SYSTEM & FIELD CONFIG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: LenseScanTheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: const [
                    Icon(Icons.cell_tower, size: 14, color: LenseScanTheme.secondary),
                    SizedBox(width: 4),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: LenseScanTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Settings List ──
            _buildSettingsList(context),
            const SizedBox(height: 16),

            // ── Sign Out Button ──
            _buildSignOutButton(context),
            const SizedBox(height: 16),

            // ── Statutory Footer ──
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.policy_outlined, size: 13, color: LenseScanTheme.outline),
                      SizedBox(width: 4),
                      Text(
                        'National Informatics Division • Legal Metrology',
                        style: TextStyle(
                          fontSize: 11,
                          color: LenseScanTheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'LenseScan v2.4.1 (Build 108) • Govt of India',
                    style: TextStyle(
                      fontSize: 10,
                      color: LenseScanTheme.outline,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeroCard(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final officerName = auth.username != null && auth.username!.isNotEmpty
        ? (auth.username == 'officer' ? 'Rajesh Kumar Sharma' : auth.username!)
        : 'Rajesh Kumar Sharma';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: LenseScanTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with verified badge
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: LenseScanTheme.surfaceContainerLow,
                ),
                padding: const EdgeInsets.all(4),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: LenseScanTheme.surfaceContainer,
                  child: const Icon(
                    Icons.person,
                    size: 48,
                    color: LenseScanTheme.onSurfaceVariant,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: LenseScanTheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Officer Identity
          Text(
            officerName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: LenseScanTheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'ID: LM-DL-4029 • Zone 4, Delhi',
            style: TextStyle(
              fontSize: 13,
              color: LenseScanTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),

          // Official Role Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: LenseScanTheme.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.shield_outlined,
                  size: 15,
                  color: LenseScanTheme.onSecondaryContainer,
                ),
                SizedBox(width: 5),
                Text(
                  'Senior Field Enforcement Officer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: LenseScanTheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Department Affiliation
          Divider(
            color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.account_balance_outlined,
                size: 15,
                color: LenseScanTheme.outline,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Ministry of Consumer Affairs, Food & Public Distribution',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: LenseScanTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(
          context,
          icon: Icons.qr_code_scanner,
          iconBg: LenseScanTheme.surfaceContainerHigh,
          iconColor: LenseScanTheme.primary,
          value: '412',
          label: 'Total Scans',
        ),
        const SizedBox(width: 8),
        _buildStatCard(
          context,
          icon: Icons.assignment_late_outlined,
          iconBg: LenseScanTheme.errorContainer.withValues(alpha: 0.6),
          iconColor: LenseScanTheme.error,
          value: '38',
          label: 'Notices Issued',
        ),
        const SizedBox(width: 8),
        _buildStatCard(
          context,
          icon: Icons.verified_user_outlined,
          iconBg: LenseScanTheme.secondaryContainer.withValues(alpha: 0.6),
          iconColor: LenseScanTheme.secondary,
          value: '99.4%',
          label: 'Accuracy',
          valueColor: LenseScanTheme.secondary,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: LenseScanTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: valueColor ?? LenseScanTheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: LenseScanTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      children: [
        _buildSettingItem(
          icon: Icons.speed,
          title: 'Device & Scanner Calibration',
          subtitle: 'Dual-lens OCR tuned • Calibrated 3d ago',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: LenseScanTheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: LenseScanTheme.outline),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingItem(
          icon: Icons.cloud_sync_outlined,
          title: 'Offline Cache & Sync',
          subtitle: 'Auto-sync on unmetered Wi-Fi',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: LenseScanTheme.tertiaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text(
                  '14 pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LenseScanTheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20, color: LenseScanTheme.outline),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingItem(
          icon: Icons.lock_clock_outlined,
          title: 'Change Security PIN & Password',
          subtitle: 'Biometrics enabled for rapid dossier sign-off',
          trailing: const Icon(Icons.chevron_right, size: 20, color: LenseScanTheme.outline),
        ),
        const SizedBox(height: 8),
        _buildSettingItem(
          icon: Icons.notifications_active_outlined,
          title: 'Notification & Alert Preferences',
          subtitle: 'Statutory alert broadcasts & raid alerts',
          trailing: const Icon(Icons.chevron_right, size: 20, color: LenseScanTheme.outline),
        ),
        const SizedBox(height: 8),
        _buildSettingItem(
          icon: Icons.menu_book_outlined,
          title: 'Legal Metrology Rules Reference',
          subtitle: 'Packaged Commodities Act (2011 & Amendments)',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bookmark_outline, size: 16, color: LenseScanTheme.primary),
              SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: LenseScanTheme.outline),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Material(
      color: LenseScanTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LenseScanTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: LenseScanTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: LenseScanTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: LenseScanTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Material(
      color: LenseScanTheme.errorContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          context.read<AuthProvider>().logout();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.logout, size: 20, color: LenseScanTheme.error),
              SizedBox(width: 8),
              Text(
                'Sign Out of Field Session',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: LenseScanTheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
