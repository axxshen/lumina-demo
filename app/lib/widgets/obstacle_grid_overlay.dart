import 'package:flutter/material.dart';
import '../services/obstacle_avoidance_service.dart';

/// Visual overlay showing the 3x3 obstacle detection grid
class ObstacleGridOverlay extends StatelessWidget {
  final ObstacleAvoidanceService obstacleService;
  final Size screenSize;

  const ObstacleGridOverlay({
    super.key,
    required this.obstacleService,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: obstacleService,
      builder: (context, child) {
        if (!obstacleService.isEnabled) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: CustomPaint(
            painter: ObstacleGridPainter(
              obstacleGrid: obstacleService.obstacleGrid,
              screenSize: screenSize,
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for drawing the obstacle grid
class ObstacleGridPainter extends CustomPainter {
  final List<bool> obstacleGrid;
  final Size screenSize;

  ObstacleGridPainter({
    required this.obstacleGrid,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int gridSize = 3;
    final double cellWidth = size.width / gridSize;
    final double cellHeight = size.height / gridSize;

    // Paint for grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Paint for central column highlight
    final centralColumnPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Paint for obstacle cells
    final dangerPaint = Paint()
      ..color = Colors.red.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final warningPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final safePaint = Paint()
      ..color = Colors.green.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw grid cells
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final index = row * gridSize + col;
        final rect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );

        // Highlight central column (column 1: indices 1, 4, 7)
        if (col == 1) {
          canvas.drawRect(rect, centralColumnPaint);
        }

        // Draw obstacle status
        if (index < obstacleGrid.length) {
          if (obstacleGrid[index]) {
            // For now, just show as danger (red)
            // In a more advanced version, you could differentiate by distance
            canvas.drawRect(rect, dangerPaint);
          } else if (col == 1) {
            // Central column is safe
            canvas.drawRect(rect, safePaint);
          }
        }

        // Draw grid lines
        canvas.drawRect(rect, gridPaint);
      }
    }

    // Draw additional grid lines for clarity
    for (int i = 0; i <= gridSize; i++) {
      // Vertical lines
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        gridPaint,
      );
      
      // Horizontal lines
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        gridPaint,
      );
    }

    // Draw status indicators
    _drawStatusIndicators(canvas, size);
  }

  void _drawStatusIndicators(Canvas canvas, Size size) {
    // Status indicator background
    final indicatorBg = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final indicatorRect = Rect.fromLTWH(
      size.width - 150,
      20,
      130,
      100,
    );

    // Draw background
    canvas.drawRRect(
      RRect.fromRectAndRadius(indicatorRect, const Radius.circular(8)),
      indicatorBg,
    );

    // Draw legend
    _drawLegendItem(canvas, size.width - 140, 35, Colors.red, "危险");
    _drawLegendItem(canvas, size.width - 140, 55, Colors.yellow, "警告");
    _drawLegendItem(canvas, size.width - 140, 75, Colors.green, "安全");
    _drawLegendItem(canvas, size.width - 140, 95, Colors.blue, "中心路径");
  }

  void _drawLegendItem(Canvas canvas, double x, double y, Color color, String text) {
    // Draw color indicator
    final colorPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 6, colorPaint);

    // Draw text (simplified - in a real implementation you'd use TextPainter)
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontFamily: 'PingFang SC',
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(x + 15, y - 6));
  }

  @override
  bool shouldRepaint(ObstacleGridPainter oldDelegate) {
    return obstacleGrid != oldDelegate.obstacleGrid ||
           screenSize != oldDelegate.screenSize;
  }
}

/// Widget for displaying obstacle avoidance status
class ObstacleStatusWidget extends StatelessWidget {
  final ObstacleAvoidanceService obstacleService;

  const ObstacleStatusWidget({
    super.key,
    required this.obstacleService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: obstacleService,
      builder: (context, child) {
        if (!obstacleService.isEnabled) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 50,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '障碍物检测',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      obstacleService.isCentralColumnClear
                          ? Icons.check_circle
                          : Icons.warning,
                      color: obstacleService.isCentralColumnClear
                          ? Colors.green
                          : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      obstacleService.isCentralColumnClear ? '前方安全' : '检测到障碍物',
                      style: TextStyle(
                        color: obstacleService.isCentralColumnClear
                            ? Colors.green
                            : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '障碍物: ${obstacleService.obstacleGrid.where((obstacle) => obstacle).length}/9',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
