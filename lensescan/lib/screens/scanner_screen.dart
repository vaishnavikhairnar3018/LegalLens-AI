/// Scanner screen — camera capture viewfinder with minimal UI.
///
/// Matches Stitch design: 3._camera_scan_viewfinder/code.html
/// Full-bleed camera preview, corner reticles, shutter button,
/// gallery import, flash toggle, Label/Barcode mode pill.
library;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/dio_client.dart';
import '../core/auth/auth_provider.dart';
import '../core/utils/camera_permission.dart';
import '../widgets/loading_overlay.dart';

/// Core scanner screen — capture product labels and submit for compliance analysis.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _capturedImageBytes;
  String? _capturedImageName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  bool _torchOn = false;
  bool _isLabelMode = true; // true=Label, false=Barcode
  late AnimationController _pulseController;

  // Live camera stream state
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = true;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _isCameraInitializing = true;
      _cameraErrorMessage = null;
    });

    try {
      if (kIsWeb) {
        // Trigger browser permission prompt first via HTML5 getUserMedia
        await requestWebCameraPermission();
      }

      final cameras = await availableCameras().timeout(
        const Duration(seconds: 15),
        onTimeout: () => <CameraDescription>[],
      );
      _availableCameras = cameras;
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage = 'No camera found or permission not granted in browser.\nPlease allow camera access and tap Retry.';
        });
        return;
      }

      // Prefer rear/back camera for label scanning
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Camera initialization timed out');
        },
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _isCameraInitializing = false;
        _cameraErrorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      String err = 'Camera access denied or unavailable.';
      final eStr = e.toString().toLowerCase();
      if (eStr.contains('notallowederror') || eStr.contains('permission')) {
        err = 'Camera permission blocked. Tap the tune/lock icon in browser URL bar to allow camera.';
      } else if (eStr.contains('securityerror') || eStr.contains('insecure') || eStr.contains('secure context')) {
        err = 'Live camera requires a secure origin. Please tap lock icon near URL to Allow Camera.';
      } else if (eStr.contains('timed out')) {
        err = 'Camera initialization timed out. Tap Allow / Retry Camera below.';
      }
      setState(() {
        _isCameraInitialized = false;
        _isCameraInitializing = false;
        _cameraErrorMessage = err;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _cameraController == null) return;
    final currentLens = _cameraController!.description.lensDirection;
    final newCamera = _availableCameras.firstWhere(
      (c) => c.lensDirection != currentLens,
      orElse: () => _availableCameras.first,
    );
    await _cameraController?.dispose();
    if (!mounted) return;
    setState(() {
      _isCameraInitialized = false;
      _isCameraInitializing = true;
    });
    try {
      final controller = CameraController(
        newCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraInitialized = true;
        _isCameraInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        _isCameraInitializing = false;
      });
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        if (_torchOn) {
          await _cameraController!.setFlashMode(FlashMode.off);
          setState(() => _torchOn = false);
        } else {
          await _cameraController!.setFlashMode(FlashMode.torch);
          setState(() => _torchOn = true);
        }
        return;
      } catch (_) {
        // Fallback for browsers / devices without torch support
      }
    }
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _handleShutterCapture() async {
    // 1. If live camera stream is active, capture photo instantly from feed
    if (_isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.isTakingPicture) {
      try {
        final XFile photo = await _cameraController!.takePicture();
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        setState(() {
          _capturedImageBytes = bytes;
          _capturedImageName = photo.name.isNotEmpty ? photo.name : 'label_scan.jpg';
          _errorMessage = null;
        });
        return;
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to capture from live stream: $e';
        });
        return;
      }
    }

    // 2. If camera not initialized, retry live camera start so it runs inside scanner
    if (!_isCameraInitializing) {
      await _initCamera();
    }
  }

  Future<void> _captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
          _capturedImageName = photo.name.isNotEmpty ? photo.name : 'label_scan.jpg';
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera access denied or unavailable.';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
          _capturedImageName = photo.name.isNotEmpty ? photo.name : 'label_scan.jpg';
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gallery access denied or unavailable.';
      });
    }
  }

  Future<void> _uploadAndScan() async {
    if (_capturedImageBytes == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          _capturedImageBytes!,
          filename: _capturedImageName ?? 'label_scan.jpg',
        ),
      });

      final response = await DioClient.instance.dio.post(
        ApiEndpoints.scan,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _capturedImageBytes = null;
          _capturedImageName = null;
        });

        // Navigate to results screen with the compliance report
        context.push('/results', extra: response.data);
      }
    } on DioException catch (e) {
      String message;
      if (e.response != null) {
        final detail = e.response!.data is Map
            ? e.response!.data['detail'] ?? 'Unknown error'
            : 'Unknown error';
        message = 'Scan failed: $detail';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        message = 'Connection timed out. Please check your network.';
      } else {
        message = 'Network error. Please try again.';
      }
      setState(() {
        _isUploading = false;
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'An unexpected error occurred.';
      });
    }
  }

  void _clearImage() {
    setState(() {
      _capturedImageBytes = null;
      _capturedImageName = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          appBar: _capturedImageBytes == null ? _buildViewfinderAppBar() : null,
          body: _capturedImageBytes != null
              ? _buildImagePreview()
              : _buildViewfinder(),
        ),

        // Upload loading overlay
        if (_isUploading)
          LoadingOverlay(
            message: 'Analyzing label...',
            progress: _uploadProgress,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildViewfinderAppBar() {
    final auth = context.watch<AuthProvider>();
    final username = auth.username ?? 'Officer';
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: LenseScanTheme.surfaceContainerLowest.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_rounded, size: 18, color: LenseScanTheme.primary),
              const SizedBox(width: 4),
              const Text(
                'LegalLens AI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: LenseScanTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      leadingWidth: 140,
      actions: [
        // Profile avatar
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: LenseScanTheme.surfaceContainerHigh,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'O',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LenseScanTheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewfinder() {
    return Container(
      color: LenseScanTheme.onSurface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Full-bleed camera area
            Expanded(
              child: Stack(
                children: [
                  // Live Camera Stream Preview
                  _buildLiveCameraView(),

                  // Scrim gradients
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              LenseScanTheme.inverseSurface.withValues(alpha: 0.7),
                              Colors.transparent,
                              Colors.transparent,
                              LenseScanTheme.inverseSurface.withValues(alpha: 0.8),
                            ],
                            stops: const [0.0, 0.2, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top toolbar: switch camera + torch
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_availableCameras.length > 1)
                          _buildCircleButton(
                            icon: Icons.flip_camera_ios_rounded,
                            selected: false,
                            onTap: _switchCamera,
                          )
                        else
                          const SizedBox(width: 44),
                        // Flash toggle
                        _buildCircleButton(
                          icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                          selected: _torchOn,
                          onTap: _toggleTorch,
                        ),
                      ],
                    ),
                  ),

                  // Center: Viewfinder reticle
                  Center(
                    child: _buildReticle(),
                  ),

                  // Error message overlay
                  if (_errorMessage != null)
                    Positioned(
                      bottom: 180,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: LenseScanTheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: LenseScanTheme.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: LenseScanTheme.onErrorContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom capture console
            Container(
              color: LenseScanTheme.onSurface.withValues(alpha: 0.95),
              padding: const EdgeInsets.only(top: 16, bottom: 20),
              child: Column(
                children: [
                  // Mode toggle pill: Label / Barcode
                  _buildModeToggle(),
                  const SizedBox(height: 20),

                  // Shutter row: gallery + shutter
                  _buildShutterRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCameraView() {
    if (_isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      return GestureDetector(
        onTap: _handleShutterCapture,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
              if (scale < 1) scale = 1 / scale;
              return ClipRect(
                child: Center(
                  child: Transform.scale(
                    scale: scale,
                    child: Center(
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (_isCameraInitializing) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF10141D),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: LenseScanTheme.primary,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Starting live camera in scanner...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Camera not available or permission denied
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF10141D),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              _cameraErrorMessage ?? 'Live camera stream not active',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initCamera,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Allow & Start Live Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LenseScanTheme.surfaceContainerLowest,
                foregroundColor: LenseScanTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _captureFromCamera,
              icon: Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white.withValues(alpha: 0.45)),
              label: Text(
                'Use phone camera app instead',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? LenseScanTheme.secondaryFixed
              : LenseScanTheme.inverseSurface.withValues(alpha: 0.6),
        ),
        child: Icon(
          icon,
          size: 22,
          color: selected ? LenseScanTheme.primary : Colors.white,
        ),
      ),
    );
  }

  Widget _buildReticle() {
    return SizedBox(
      width: 240,
      height: 320,
      child: Stack(
        children: [
          // Corner reticles
          _buildCorner(Alignment.topLeft, BorderRadius.only(topLeft: Radius.circular(16))),
          _buildCorner(Alignment.topRight, BorderRadius.only(topRight: Radius.circular(16))),
          _buildCorner(Alignment.bottomLeft, BorderRadius.only(bottomLeft: Radius.circular(16))),
          _buildCorner(Alignment.bottomRight, BorderRadius.only(bottomRight: Radius.circular(16))),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment, BorderRadius borderRadius) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return Positioned(
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: LenseScanTheme.secondaryFixed, width: 2) : BorderSide.none,
            bottom: isTop ? BorderSide.none : BorderSide(color: LenseScanTheme.secondaryFixed, width: 2),
            left: isLeft ? BorderSide(color: LenseScanTheme.secondaryFixed, width: 2) : BorderSide.none,
            right: isLeft ? BorderSide.none : BorderSide(color: LenseScanTheme.secondaryFixed, width: 2),
          ),
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LenseScanTheme.inverseSurface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModePill('Label', _isLabelMode, () {
            setState(() => _isLabelMode = true);
          }),
          _buildModePill('Barcode', !_isLabelMode, () {
            setState(() => _isLabelMode = false);
          }),
        ],
      ),
    );
  }

  Widget _buildModePill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: active ? LenseScanTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.12,
            color: active ? LenseScanTheme.primary : LenseScanTheme.surfaceDim,
          ),
        ),
      ),
    );
  }

  Widget _buildShutterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gallery picker
          GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LenseScanTheme.inverseSurface.withValues(alpha: 0.65),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 32),

          // Shutter button
          GestureDetector(
            onTap: _handleShutterCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 4,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Spacer to balance gallery button
          const SizedBox(width: 76),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Image preview
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: LenseScanTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: LenseScanTheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        _capturedImageBytes!,
                        fit: BoxFit.contain,
                      ),
                      // Top overlay bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: LenseScanTheme.secondaryFixed, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Image captured',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _clearImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LenseScanTheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: LenseScanTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: LenseScanTheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _captureFromCamera,
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LenseScanTheme.onSurface,
                        backgroundColor: LenseScanTheme.surfaceContainerHigh,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _uploadAndScan,
                      icon: const Icon(Icons.document_scanner_rounded, size: 18),
                      label: const Text('Scan'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
