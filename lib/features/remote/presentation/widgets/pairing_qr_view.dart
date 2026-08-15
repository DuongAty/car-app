import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

/// Static QR code, painted once.
///
/// Drawn with a `CustomPainter` over the pure-Dart `qr` package rather than a
/// widget library: the matrix never changes while it is on screen, so this is
/// one rasterization behind a [RepaintBoundary] instead of a widget tree of a
/// thousand cells. No animation — a car head unit has no spare GPU for one.
class PairingQrView extends StatefulWidget {
  const PairingQrView({super.key, required this.data, this.size = 260});

  /// The `wektv://pair?code=…` string. See `pairingQrPayload`.
  final String data;

  final double size;

  @override
  State<PairingQrView> createState() => _PairingQrViewState();
}

class _PairingQrViewState extends State<PairingQrView> {
  late QrImage _image = _matrixOf(widget.data);

  @override
  void didUpdateWidget(PairingQrView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Encoding runs eight mask passes, so it happens only when the code
    // actually changes — never on a countdown tick.
    if (oldWidget.data != widget.data) {
      _image = _matrixOf(widget.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Scanners need a light quiet zone; this is the one deliberately
          // bright surface in the whole app.
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: CustomPaint(
          painter: _QrPainter(_image),
          size: Size.square(widget.size),
        ),
      ),
    );
  }

  static QrImage _matrixOf(String data) {
    return QrImage(
      QrCode.fromData(
        data: data,
        // M keeps the code readable from across a car cabin without inflating
        // the module count the way Q/H would.
        errorCorrectLevel: QrErrorCorrectLevel.M,
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    if (count == 0) {
      return;
    }
    final cell = size.width / count;
    final paint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!image.isDark(row, col)) {
          continue;
        }
        // Half-pixel overdraw closes the hairline seams that appear between
        // adjacent modules when the cell size is fractional.
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      !identical(oldDelegate.image, image);
}
