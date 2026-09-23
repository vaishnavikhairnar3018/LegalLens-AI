/// Loading overlay — processing/analysis screen.
///
/// Matches Stitch design: 4._processing_analysis_screen/code.html
/// Concentric ring animation, sequential step progress, clean centered layout.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Full-screen loading overlay with animated scanner and step progress.
class LoadingOverlay extends StatefulWidget {
  final String message;
  final double? progress;

  const LoadingOverlay({
    super.key,
    this.message = 'Analyzing Label',
    this.progress,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  // Map progress to step index: 0-0.33=step1, 0.33-0.66=step2, 0.66-1.0=step3
  int get _currentStep {
    final p = widget.progress ?? 0.0;
    if (p >= 0.66) return 2;
    if (p >= 0.33) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LenseScanTheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // App bar
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: LenseScanTheme.onSurface),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Scanning',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: LenseScanTheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Scanner Animation ──
              _buildScannerGraphic(),
              const SizedBox(height: 20),

              // ── Status Heading ──
              Text(
                widget.message,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: LenseScanTheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 20),

              // ── Progress Steps ──
              _buildProgressSteps(),
              const SizedBox(height: 16),

              // ── Progress percentage ──
              if (widget.progress != null)
                Text(
                  '${(widget.progress! * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: LenseScanTheme.secondary.withValues(alpha: 0.8),
                  ),
                ),

              const Spacer(flex: 3),

              // ── Cancel Button ──
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      backgroundColor: LenseScanTheme.surfaceContainer,
                      foregroundColor: LenseScanTheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildScannerGraphic() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: LenseScanTheme.secondary.withValues(alpha: 0.15),
                width: 1,
              ),
              color: LenseScanTheme.secondaryFixed.withValues(alpha: 0.1),
            ),
          ),

          // Mid ring
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: LenseScanTheme.secondary.withValues(alpha: 0.25),
                width: 1,
              ),
              color: LenseScanTheme.secondaryContainer.withValues(alpha: 0.2),
            ),
          ),

          // Inner ring with spinning arc
          SizedBox(
            width: 128,
            height: 128,
            child: AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _spinController.value * 2 * math.pi,
                  child: CustomPaint(
                    painter: _ArcPainter(
                      trackColor: LenseScanTheme.secondary.withValues(alpha: 0.3),
                      arcColor: LenseScanTheme.secondary,
                    ),
                  ),
                );
              },
            ),
          ),

          // Core icon
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LenseScanTheme.primary,
              boxShadow: [
                BoxShadow(
                  color: LenseScanTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.document_scanner_rounded,
              size: 36,
              color: LenseScanTheme.primaryFixed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    final steps = [
      _StepData('Text Extraction', 0),
      _StepData('Rule Check', 1),
      _StepData('Registry', 2),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LenseScanTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: steps.map((step) {
          final isDone = _currentStep > step.index;
          final isActive = _currentStep == step.index;
          final isPending = _currentStep < step.index;

          return Padding(
            padding: EdgeInsets.only(bottom: step.index < 2 ? 12 : 0),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? LenseScanTheme.secondaryContainer
                        : isActive
                            ? LenseScanTheme.primaryFixed
                            : LenseScanTheme.surfaceContainer,
                  ),
                  child: isDone
                      ? Icon(Icons.check, size: 18, color: LenseScanTheme.onSecondaryContainer)
                      : isActive
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: LenseScanTheme.primary,
                              ),
                            )
                          : Icon(Icons.radio_button_unchecked, size: 18, color: LenseScanTheme.outline),
                ),
                const SizedBox(width: 12),

                // Label
                Expanded(
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isPending
                          ? LenseScanTheme.onSurface.withValues(alpha: 0.6)
                          : LenseScanTheme.onSurface,
                    ),
                  ),
                ),

                // Status label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDone
                        ? LenseScanTheme.surfaceContainer
                        : isActive
                            ? LenseScanTheme.primaryFixedDim.withValues(alpha: 0.4)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    isDone ? 'Done' : isActive ? 'In progress' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isDone
                          ? LenseScanTheme.secondary
                          : isActive
                              ? LenseScanTheme.primaryContainer
                              : LenseScanTheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StepData {
  final String label;
  final int index;
  const _StepData(this.label, this.index);
}

class _ArcPainter extends CustomPainter {
  final Color trackColor;
  final Color arcColor;

  _ArcPainter({required this.trackColor, required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2 - 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, trackPaint);

    // Arc
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi / 3, // 60 degree arc
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
