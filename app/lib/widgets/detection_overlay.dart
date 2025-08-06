import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/depth_estimation_service.dart';

/// A custom painter that draws depth values for YOLO detections
class DetectionOverlayPainter extends CustomPainter {
  final List<YOLOResult> detections;
  final List<DepthEstimationResult> depthResults;
  final Size viewSize;
  final bool showDepthEstimation;

  DetectionOverlayPainter({
    required this.detections,
    required this.depthResults,
    required this.viewSize,
    required this.showDepthEstimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Only draw depth indicators if the setting is enabled
    if (!showDepthEstimation) return;
    
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final depthResult = i < depthResults.length ? depthResults[i] : null;
      
      // Calculate center point from normalized coordinates
      final centerX = (detection.normalizedBox.left + detection.normalizedBox.right) / 2;
      final centerY = (detection.normalizedBox.top + detection.normalizedBox.bottom) / 2;

      // Convert normalized coordinates to screen coordinates
      final screenX = centerX * size.width;
      final screenY = centerY * size.height;
      final center = Offset(screenX, screenY);

      if (depthResult != null) {
        // Draw depth value instead of center marker
        _drawDepthIndicator(canvas, center, depthResult);
      } else {
        // Fallback to simple center marker if no depth data
        _drawSimpleCenterMarker(canvas, center);
      }
    }
  }
  
  /// Draw depth indicator with value and confidence visualization
  void _drawDepthIndicator(Canvas canvas, Offset center, DepthEstimationResult depthResult) {
    final depthText = depthResult.getFormattedDepth();
    
    // Choose colors based on confidence level
    Color backgroundColor;
    Color textColor;
    
    if (depthResult.confidence >= 0.7) {
      backgroundColor = Colors.green.withValues(alpha: 0.9);
      textColor = Colors.white;
    } else if (depthResult.confidence >= 0.4) {
      backgroundColor = Colors.orange.withValues(alpha: 0.9);
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.red.withValues(alpha: 0.9);
      textColor = Colors.white;
    }
    
    // Create text painter for depth value
    final textPainter = TextPainter(
      text: TextSpan(
        text: depthText,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Calculate background rectangle size
    const padding = 6.0;
    final backgroundRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: textPainter.width + padding * 2,
        height: textPainter.height + padding * 2,
      ),
      const Radius.circular(8),
    );
    
    // Draw background with confidence-based color
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(backgroundRect, backgroundPaint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(backgroundRect, borderPaint);
    
    // Draw depth text centered
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
    
    // Draw small confidence indicator (dot)
    _drawConfidenceIndicator(canvas, center, backgroundRect, depthResult.confidence);
  }
  
  /// Draw confidence indicator as a small colored dot
  void _drawConfidenceIndicator(Canvas canvas, Offset center, RRect backgroundRect, double confidence) {
    Color indicatorColor;
    if (confidence >= 0.8) {
      indicatorColor = Colors.green;
    } else if (confidence >= 0.6) {
      indicatorColor = Colors.yellow;
    } else if (confidence >= 0.4) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.red;
    }
    
    // Position indicator at top-right corner of the background
    final indicatorCenter = Offset(
      backgroundRect.right - 6,
      backgroundRect.top + 6,
    );
    
    final indicatorPaint = Paint()
      ..color = indicatorColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(indicatorCenter, 3, indicatorPaint);
    
    // White border for visibility
    final indicatorBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawCircle(indicatorCenter, 3, indicatorBorderPaint);
  }
  
  /// Fallback method to draw simple center marker when no depth data is available
  void _drawSimpleCenterMarker(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw center point marker
    canvas.drawCircle(center, 8, strokePaint);
    canvas.drawCircle(center, 6, paint);

    // Draw crosshair lines
    final crosshairPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;

    const crosshairLength = 15.0;
    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - crosshairLength, center.dy),
      Offset(center.dx + crosshairLength, center.dy),
      crosshairPaint,
    );
    // Vertical line  
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairLength),
      Offset(center.dx, center.dy + crosshairLength),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(DetectionOverlayPainter oldDelegate) {
    return detections != oldDelegate.detections ||
           depthResults != oldDelegate.depthResults ||
           viewSize != oldDelegate.viewSize;
  }
}

/// Widget that overlays detection depth values on top of the YOLO camera view
class DetectionOverlay extends StatefulWidget {
  final List<YOLOResult> detections;
  final List<DepthEstimationResult> depthResults;
  final Widget child;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.depthResults,
    required this.child,
  });

  @override
  State<DetectionOverlay> createState() => _DetectionOverlayState();
}

class _DetectionOverlayState extends State<DetectionOverlay> {
  bool _showDepthEstimation = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void didUpdateWidget(DetectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload settings when widget updates (when parent rebuilds)
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showDepthEstimation = prefs.getBool('show_depth_estimation') ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: CustomPaint(
            painter: DetectionOverlayPainter(
              detections: widget.detections,
              depthResults: widget.depthResults,
              viewSize: MediaQuery.of(context).size,
              showDepthEstimation: _showDepthEstimation,
            ),
          ),
        ),
      ],
    );
  }
}
