/// Results screen — compliance report with donut chart and declaration checklist.
///
/// Matches Stitch design: 5._compliance_results_report/code.html
/// Product name header, compliance score, donut chart, declaration rows,
/// bottom sticky export buttons. SHA-256 badge kept as collapsible.
library;

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/dio_client.dart';
import '../core/utils/file_downloader.dart';
import '../core/utils/product_formatter.dart';
import '../models/scan_result_model.dart';
import '../widgets/compliance_card.dart';

/// Compliance report display screen.
class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ResultsScreen({super.key, required this.report});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late ScanResultModel _result;
  bool _isLoadingFullReport = false;
  bool _isDownloadingPdf = false;
  bool _isDownloadingDocx = false;
  String? _fetchError;
  bool _showHashDetail = false;

  @override
  void initState() {
    super.initState();
    _result = ScanResultModel.fromJson(widget.report);
    // If opened from history list, declarations list might be empty. Fetch full record.
    if (_result.declarations.isEmpty && _result.scanId.isNotEmpty) {
      _loadFullInspection();
    }
  }

  Future<void> _loadFullInspection() async {
    setState(() {
      _isLoadingFullReport = true;
      _fetchError = null;
    });

    try {
      final response = await DioClient.instance.dio.get(
        ApiEndpoints.inspectionDetail(_result.scanId),
      );
      if (response.data is Map<String, dynamic>) {
        setState(() {
          _result = ScanResultModel.fromJson(response.data as Map<String, dynamic>);
          _isLoadingFullReport = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingFullReport = false;
        _fetchError = 'Could not load full declaration details: $e';
      });
    }
  }

  Future<void> _downloadExport({required bool isDocx}) async {
    if (_result.scanId.isEmpty) {
      _showToast('Cannot export: No Inspection ID found');
      return;
    }

    setState(() {
      if (isDocx) {
        _isDownloadingDocx = true;
      } else {
        _isDownloadingPdf = true;
      }
    });

    final endpoint = isDocx
        ? ApiEndpoints.inspectionDocx(_result.scanId)
        : ApiEndpoints.inspectionPdf(_result.scanId);

    try {
      final response = await DioClient.instance.dio.get<List<int>>(
        endpoint,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': isDocx ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' : 'application/pdf'},
        ),
      );

      final bytes = response.data;
      final byteCount = bytes?.length ?? 0;
      final typeStr = isDocx ? 'DOCX' : 'PDF';
      final ext = isDocx ? 'docx' : 'pdf';
      final mimeType = isDocx
          ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          : 'application/pdf';
      final scanSubId = _result.scanId.length > 8 ? _result.scanId.substring(0, 8) : _result.scanId;
      final filename = 'LMPC_${scanSubId}_$typeStr.$ext';

      if (bytes != null && bytes.isNotEmpty) {
        downloadFile(bytes, filename, mimeType);
      }

      if (mounted) {
        _showToast('$typeStr generated (${(byteCount / 1024).toStringAsFixed(1)} KB)');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['detail'] ?? 'Export failed')
          : 'Export request failed';
      if (mounted) _showToast('Export Error: $msg');
    } catch (e) {
      if (mounted) _showToast('Download failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (isDocx) {
            _isDownloadingDocx = false;
          } else {
            _isDownloadingPdf = false;
          }
        });
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyHashToClipboard(String hash) {
    Clipboard.setData(ClipboardData(text: hash));
    _showToast('SHA-256 hash copied');
  }

  // Compute counts for donut chart
  int get _reviewCount => _result.declarations.where((d) =>
      d.coverageReviewRequired || d.placementReviewRequired || d.fontReviewRequired).length;
  int get _compliantCount => _result.declarations.where((d) =>
      d.compliant && !d.coverageReviewRequired && !d.placementReviewRequired && !d.fontReviewRequired).length;
  int get _violationCount => _result.declarations.where((d) =>
      !d.compliant && !d.coverageReviewRequired && !d.placementReviewRequired && !d.fontReviewRequired).length;
  bool get _hasReviewItems =>
      _result.placementReviewRequired ||
      _result.coverageReviewRequired ||
      _result.fontReviewRequired ||
      _reviewCount > 0;

  String get _compliancePercent {
    if (_result.totalFields == 0) return '0%';
    final pct = (_compliantCount / _result.totalFields * 100).toStringAsFixed(1);
    return '$pct%';
  }

  // Format product name cleanly
  String get _productName => formatProductName(_result.imageFilename, maxLength: 30);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/scanner'),
        ),
        title: const Text('Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 20),
            tooltip: 'Share Report',
            onPressed: () => _showToast('Report link copied'),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Product Name Hero ──
                _buildProductHero(),
                const SizedBox(height: 14),

                // ── Score & Donut Chart ──
                _buildScoreSection(),
                const SizedBox(height: 14),

                // ── Geometry Review Banner ──
                if (_hasReviewItems) ...[
                  _buildReviewBanner(),
                  const SizedBox(height: 14),
                ],

                // ── SHA-256 Evidence Badge (collapsible) ──
                if (_result.imageHashSha256 != null &&
                    _result.imageHashSha256!.isNotEmpty) ...[
                  _buildHashBadge(),
                  const SizedBox(height: 14),
                ],

                // ── Declarations Checklist ──
                _buildDeclarationsSection(),
              ],
            ),
          ),

          // ── Bottom Sticky Export Buttons ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomExportBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHero() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LenseScanTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _productName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: LenseScanTheme.onSurface,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LenseScanTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 22, color: LenseScanTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection() {
    final hasReview = _hasReviewItems;
    final isCompliant = _result.overallCompliant && !hasReview && _violationCount == 0;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (hasReview) {
      badgeBg = const Color(0xFFFEF3C7); // amber-100
      badgeText = const Color(0xFFB45309); // amber-700
      badgeLabel = 'Review Required';
    } else if (isCompliant) {
      badgeBg = LenseScanTheme.secondaryContainer;
      badgeText = LenseScanTheme.onSecondaryContainer;
      badgeLabel = 'Compliant';
    } else {
      badgeBg = LenseScanTheme.errorContainer;
      badgeText = LenseScanTheme.onErrorContainer;
      badgeLabel = 'Non-Compliant';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LenseScanTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Score header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _compliancePercent,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.08,
                  color: LenseScanTheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donut chart
          _buildDonutChart(),
          const SizedBox(height: 14),

          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildDonutChart() {
    final total = _result.totalFields > 0 ? _result.totalFields : 1;
    final compliant = _compliantCount;
    final violation = _violationCount;
    final review = _reviewCount;

    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _DonutPainter(
          compliant: compliant,
          violation: violation,
          review: review,
          total: total,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_result.totalFields} Rules',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: LenseScanTheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Checked',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: LenseScanTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _buildLegendItem(
          color: LenseScanTheme.secondary,
          label: 'Compliant',
          count: _compliantCount,
          bgColor: LenseScanTheme.surfaceContainerLow,
        ),
        const SizedBox(width: 4),
        _buildLegendItem(
          color: LenseScanTheme.error,
          label: 'Violation',
          count: _violationCount,
          bgColor: LenseScanTheme.errorContainer.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 4),
        _buildLegendItem(
          color: LenseScanTheme.warningAmber,
          label: 'Review',
          count: _reviewCount,
          bgColor: LenseScanTheme.warningAmberLight,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int count,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label $count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: LenseScanTheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LenseScanTheme.warningAmberLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LenseScanTheme.warningAmberBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, size: 20, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Net Quantity — needs manual check',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashBadge() {
    final hash = _result.imageHashSha256!;
    return GestureDetector(
      onTap: () => setState(() => _showHashDetail = !_showHashDetail),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LenseScanTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: LenseScanTheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 16,
                    color: LenseScanTheme.secondary),
                const SizedBox(width: 6),
                Text(
                  'Evidence Integrity Seal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.33,
                    color: LenseScanTheme.secondary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _copyHashToClipboard(hash),
                  child: Icon(Icons.copy_rounded, size: 14,
                      color: LenseScanTheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Icon(
                  _showHashDetail ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: LenseScanTheme.onSurfaceVariant,
                ),
              ],
            ),
            if (_showHashDetail) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: LenseScanTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hash,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: LenseScanTheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeclarationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Text(
                'Declarations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: LenseScanTheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              if (_isLoadingFullReport) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (_fetchError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _fetchError!,
              style: TextStyle(
                color: LenseScanTheme.warningAmber,
                fontSize: 13,
              ),
            ),
          ),

        ..._result.declarations.map(
          (decl) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ComplianceCard(declaration: decl),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomExportBar() {
    return Container(
      decoration: BoxDecoration(
        color: LenseScanTheme.surfaceContainerLowest.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              // Export PDF
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    onPressed: _isDownloadingPdf
                        ? null
                        : () => _downloadExport(isDocx: false),
                    icon: _isDownloadingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 20),
                    label: const Text('Export PDF'),
                    style: TextButton.styleFrom(
                      backgroundColor: LenseScanTheme.surfaceContainerHigh,
                      foregroundColor: LenseScanTheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Export Notice (DOCX)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloadingDocx
                        ? null
                        : () => _downloadExport(isDocx: true),
                    icon: _isDownloadingDocx
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.description_outlined, size: 20),
                    label: const Text('Export Notice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LenseScanTheme.primary,
                      foregroundColor: LenseScanTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF003633).withValues(alpha: 0.3),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom donut chart painter.
class _DonutPainter extends CustomPainter {
  final int compliant;
  final int violation;
  final int review;
  final int total;

  _DonutPainter({
    required this.compliant,
    required this.violation,
    required this.review,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 22.0;

    // Background track
    final trackPaint = Paint()
      ..color = LenseScanTheme.surfaceContainerLow
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;

    // Compliant segment
    if (compliant > 0) {
      final sweep = (compliant / total) * 2 * math.pi;
      final paint = Paint()
        ..color = LenseScanTheme.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
    }

    // Violation segment
    if (violation > 0) {
      final compliantSweep = (compliant / total) * 2 * math.pi;
      final gap = 0.06; // small gap between segments
      final sweep = (violation / total) * 2 * math.pi;
      final paint = Paint()
        ..color = LenseScanTheme.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle + compliantSweep + gap, sweep - gap, false, paint);
    }

    // Review segment
    if (review > 0) {
      final prevSweep = ((compliant + violation) / total) * 2 * math.pi;
      final gap = 0.06;
      final sweep = (review / total) * 2 * math.pi;
      final paint = Paint()
        ..color = LenseScanTheme.warningAmber
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle + prevSweep + gap, sweep - gap, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
