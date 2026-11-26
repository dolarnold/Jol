import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The phone camera, reading ticket QR codes.
///
/// The camera sees the same code many times a second, so [onCode] gets each
/// code once while it stays in view (again only after it was out of view for a
/// few seconds). While [paused] is true, new codes are ignored (e.g. while the
/// last one is still being checked).
///
/// The camera stops while JOL is in the background and starts again when the
/// person comes back.
class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key, required this.onCode, this.paused = false});

  final ValueChanged<String> onCode;
  final bool paused;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  StreamSubscription<BarcodeCapture>? _subscription;
  String? _last;
  var _lastSeenAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.barcodes.listen(_onDetect);
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera permission prompt also changes the app state: leave it alone
    // until the camera is allowed.
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _subscription ??= _controller.barcodes.listen(_onDetect);
        unawaited(_start());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(_stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
    unawaited(_controller.dispose());
  }

  Future<void> _start() async {
    try {
      await _controller.start();
    } on Object {
      // No camera or no permission: the error view below says what to do.
    }
  }

  Future<void> _stop() async {
    try {
      await _controller.stop();
    } on Object {
      // Already stopped.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      if (value == _last) {
        // Still in front of the camera: once is enough (otherwise a guest who
        // keeps holding up their phone shows as "already let in"). It counts
        // again once it has been out of view for a few seconds.
        final away = now.difference(_lastSeenAt) > const Duration(seconds: 3);
        _lastSeenAt = now;
        if (!away || widget.paused) return;
      } else {
        if (widget.paused) return;
        _last = value;
        _lastSeenAt = now;
      }
      widget.onCode(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error) => _CameraProblem(
                denied: error.errorCode == MobileScannerErrorCode.permissionDenied,
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: IconButton.filledTonal(
                tooltip: 'Torch',
                onPressed: () => unawaited(_controller.toggleTorch().catchError((Object _) {})),
                icon: const Icon(Icons.flashlight_on_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.denied});

  final bool denied;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'JOL can’t use the camera. Allow it in your phone’s settings, or type the code below.'
                  : 'The camera isn’t working. Type the code below instead.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
