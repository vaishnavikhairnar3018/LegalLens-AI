/// Home screen — Executive enforcement overview & quick scan launcher.
///
/// Provides field officers with a command dashboard:
/// - Officer greeting & active duty status
/// - Primary "Start Inspection" action card
/// - Key metrics (Scans, Compliance Rate, Pending Reviews)
/// - Recent field inspection history
/// - LMPC 2011 statutory declaration quick reference
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/dio_client.dart';
import '../core/auth/auth_provider.dart';
import '../core/utils/product_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _recentInspections = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = DioClient.instance.dio;

      // Fetch summary KPIs and recent inspections in parallel
      final summaryFuture = dio.get(ApiEndpoints.dashboardSummary);
      final inspectionsFuture = dio.get('${ApiEndpoints.inspections}?limit=4');

      final results = await Future.wait([
        summaryFuture.catchError((_) => Response(requestOptions: RequestOptions(), statusCode: 500)),
        inspectionsFuture.catchError((_) => Response(requestOptions: RequestOptions(), statusCode: 500)),
      ]);

      Map<String, dynamic>? summaryData;
      if (results[0].statusCode == 200 && results[0].data is Map<String, dynamic>) {
        summaryData = results[0].data as Map<String, dynamic>;
      }

      List<Map<String, dynamic>> inspectionsList = [];
      if (results[1].statusCode == 200 && results[1].data is List) {
        inspectionsList = (results[1].data as List).cast<Map<String, dynamic>>();
      }

      if (mounted) {
        setState(() {
          _summary = summaryData;
          _recentInspections = inspectionsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load dashboard data: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatProductName(String? filename) {
    return formatProductName(filename, maxLength: 26);
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        return 'Today $hour:$minute $ampm';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final username = auth.username;
    String officerName = 'Enforcement Officer';
    if (username != null && username.isNotEmpty) {
      if (username.toLowerCase().startsWith('officer_')) {
        final clean = username.substring(8);
        officerName = clean.isNotEmpty
            ? 'Officer ${clean[0].toUpperCase()}${clean.substring(1)}'
            : 'Officer';
      } else if (username.toLowerCase().startsWith('officer')) {
        final clean = username.substring(7);
        officerName = clean.isNotEmpty
            ? 'Officer ${clean[0].toUpperCase()}${clean.substring(1)}'
            : 'Officer';
      } else {
        officerName = 'Officer ${username[0].toUpperCase()}${username.substring(1)}';
      }
    }
    final role = auth.role ?? 'officer';

    return Scaffold(
      backgroundColor: LenseScanTheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: LenseScanTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Bar ──
                _buildHeader(officerName, role),
                const SizedBox(height: 20),

                // ── Error Banner (if any) ──
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: LenseScanTheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: LenseScanTheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(fontSize: 12, color: LenseScanTheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Hero Scan Card ──
                _buildHeroScanCard(context),
                const SizedBox(height: 20),

                // ── KPI Metrics Section ──
                _buildMetricsSection(),
                const SizedBox(height: 24),

                // ── Recent Inspections Section ──
                _buildRecentInspectionsSection(context),
                const SizedBox(height: 24),

                // ── Statutory LMPC Rules Reference ──
                _buildRulesReference(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String officerName, String role) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LenseScanTheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: LenseScanTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.security_rounded,
                color: LenseScanTheme.onPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEGALLENS AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: LenseScanTheme.primary.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  officerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: LenseScanTheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: LenseScanTheme.secondaryFixed.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: LenseScanTheme.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: LenseScanTheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                role.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: LenseScanTheme.secondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroScanCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F3B36),
            Color(0xFF134E4A),
            Color(0xFF0D332F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF134E4A).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/scanner'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'LIVE SCANNER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Start Package Inspection',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Automated LMPC 2011 compliance check with real-time optical scale recovery.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/scanner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F3B36),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text(
                          'Open Camera Viewfinder',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    final total = _summary?['total_inspections'] ?? _recentInspections.length;
    final rate = (_summary?['compliance_rate_pct'] as num?)?.toDouble() ??
        (_calculateLocalRate());
    final violations = _summary?['non_compliant_count'] ??
        _recentInspections.where((i) => i['overall_compliant'] == false).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enforcement Overview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LenseScanTheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricCard(
              title: 'Total Scans',
              value: '$total',
              icon: Icons.inventory_2_outlined,
              iconColor: LenseScanTheme.primary,
              bgColor: LenseScanTheme.surfaceContainerLow,
            ),
            const SizedBox(width: 10),
            _buildMetricCard(
              title: 'Compliance',
              value: '${rate.toStringAsFixed(0)}%',
              icon: Icons.verified_rounded,
              iconColor: LenseScanTheme.secondary,
              bgColor: const Color(0xFFE8F5E9),
            ),
            const SizedBox(width: 10),
            _buildMetricCard(
              title: 'Flagged',
              value: '$violations',
              icon: Icons.warning_amber_rounded,
              iconColor: LenseScanTheme.error,
              bgColor: LenseScanTheme.errorContainer.withValues(alpha: 0.4),
            ),
          ],
        ),
      ],
    );
  }

  double _calculateLocalRate() {
    if (_recentInspections.isEmpty) return 0.0;
    final compliant = _recentInspections.where((i) => i['overall_compliant'] == true).length;
    return (compliant / _recentInspections.length) * 100;
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: LenseScanTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: LenseScanTheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
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

  Widget _buildRecentInspectionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Field Scans',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LenseScanTheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/history'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: LenseScanTheme.primary,
              ),
              child: const Row(
                children: [
                  Text('View All', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_recentInspections.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: LenseScanTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Icon(Icons.camera_alt_outlined, size: 40, color: LenseScanTheme.outlineVariant),
                const SizedBox(height: 10),
                const Text(
                  'No inspections recorded yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: LenseScanTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Captured scans will appear here automatically.',
                  style: TextStyle(fontSize: 12, color: LenseScanTheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else
          ..._recentInspections.map((insp) => _buildRecentItemCard(context, insp)),
      ],
    );
  }

  Widget _buildRecentItemCard(BuildContext context, Map<String, dynamic> insp) {
    final bool isCompliant = insp['overall_compliant'] == true;
    final bool hasReview = insp['placement_review_required'] == true ||
        insp['coverage_review_required'] == true ||
        insp['font_review_required'] == true;

    Color badgeBg;
    Color badgeColor;
    String badgeText;

    if (hasReview) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeColor = const Color(0xFFB45309);
      badgeText = 'Review';
    } else if (isCompliant) {
      badgeBg = LenseScanTheme.secondaryFixed.withValues(alpha: 0.35);
      badgeColor = LenseScanTheme.secondary;
      badgeText = 'Compliant';
    } else {
      badgeBg = LenseScanTheme.errorContainer;
      badgeColor = LenseScanTheme.error;
      badgeText = 'Violation';
    }

    final filename = insp['image_filename'] as String? ?? 'Product';
    final timestamp = insp['created_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: LenseScanTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.push('/results', extra: insp);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: LenseScanTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 20,
                    color: LenseScanTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatProductName(filename),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: LenseScanTheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: LenseScanTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRulesReference() {
    final rules = [
      'Maximum Retail Price (MRP)',
      'Net Quantity & Units',
      'Manufacturer Name & Address',
      'Month & Year of Manufacture',
      'Best Before / Expiry Date',
      'Consumer Care Contact Details',
      'Country of Origin',
      'Generic Commodity Name',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LenseScanTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LenseScanTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, size: 18, color: LenseScanTheme.primary),
              const SizedBox(width: 8),
              Text(
                'LMPC Rules 2011 — Mandatory Checklist',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: LenseScanTheme.primary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Rule 6 mandates all 8 statutory declarations on the Principal Display Panel (PDP) adhering to Schedule II font height brackets.',
            style: TextStyle(
              fontSize: 11,
              color: LenseScanTheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: rules.map((r) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 12, color: LenseScanTheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    r,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: LenseScanTheme.onSurface,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
