import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scanner un QR Code',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              if (_isProcessing) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final String? code = barcodes.first.rawValue;
              if (code == null || code.isEmpty) return;

              setState(() => _isProcessing = true);
              
              // Return the scanned code
              Navigator.pop(context, code);
            },
          ),

          // Overlay with scanning frame
          Container(
            decoration: ShapeDecoration(
              shape: QRScannerOverlayShape(
                borderColor: const Color(0xFF1C28F0),
                borderRadius: 20,
                borderLength: 30,
                borderWidth: 4,
                cutOutSize: 250,
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Placez le QR code dans le cadre',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class QRScannerOverlayShape extends ShapeBorder {
  const QRScannerOverlayShape({
    this.borderColor = const Color(0xFF1C28F0),
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
  }) : cutOutSize = cutOutSize ?? 250;

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.only(bottom: 0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Size size) {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, 0)
        ..close();
    }

    return _getLeftTopPath(rect.size)
      ..addPath(
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                (rect.width - cutOutSize) / 2,
                (rect.height - cutOutSize) / 2,
                cutOutSize,
                cutOutSize,
              ),
              Radius.circular(borderRadius),
            ),
          )
          ..fillType = PathFillType.evenOdd,
        Offset.zero,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidthSize / 2;
    final mPath = Path();

    // Border calculations
    mPath.addPath(_getLeftTopPath(rect.size), Offset.zero);
    mPath.addPath(
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              (width - cutOutSize) / 2,
              (height - cutOutSize) / 2,
              cutOutSize,
              cutOutSize,
            ),
            Radius.circular(borderRadius),
          ),
        )
        ..fillType = PathFillType.evenOdd,
      Offset.zero,
    );

    canvas.drawPath(mPath, Paint()..color = overlayColor);
    
    // Draw borders
    final borderRect = Rect.fromLTWH(
      (width - cutOutSize) / 2 - borderOffset,
      (height - cutOutSize) / 2 - borderOffset,
      cutOutSize + borderWidthSize,
      cutOutSize + borderWidthSize,
    );
    
    canvas.drawRect(
      borderRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  ShapeBorder scale(double t) => QRScannerOverlayShape(
        borderColor: borderColor,
        borderWidth: borderWidth,
        overlayColor: overlayColor,
      );

  Path _getLeftTopPath(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, 0)
      ..close();
  }
}
