import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo_result.dart';

/// A utility class for tracking center point movements and analyzing detected object positions
class CenterPointTracker {
  final List<List<Offset>> _centerPointHistory = [];
  final int _maxHistoryLength;

  CenterPointTracker({int maxHistoryLength = 10}) : _maxHistoryLength = maxHistoryLength;

  /// Add a new frame of center points to the history
  void addFrame(List<YOLOResult> detections) {
    final centerPoints = detections.map((detection) {
      final box = detection.normalizedBox;
      final centerX = (box.left + box.right) / 2;
      final centerY = (box.top + box.bottom) / 2;
      return Offset(centerX, centerY);
    }).toList();

    _centerPointHistory.add(centerPoints);

    // Keep only the last N frames
    if (_centerPointHistory.length > _maxHistoryLength) {
      _centerPointHistory.removeAt(0);
    }
  }

  /// Get the current center points (most recent frame)
  List<Offset> getCurrentCenterPoints() {
    if (_centerPointHistory.isEmpty) return [];
    return _centerPointHistory.last;
  }

  /// Get center points from a specific frame ago (0 = current, 1 = previous, etc.)
  List<Offset> getCenterPointsFromFrame(int framesAgo) {
    if (framesAgo >= _centerPointHistory.length || framesAgo < 0) return [];
    return _centerPointHistory[_centerPointHistory.length - 1 - framesAgo];
  }

  /// Calculate movement vectors for objects between current and previous frame
  /// Returns a list of movement vectors (dx, dy) for each tracked object
  List<Offset> getMovementVectors() {
    if (_centerPointHistory.length < 2) return [];
    
    final current = _centerPointHistory.last;
    final previous = _centerPointHistory[_centerPointHistory.length - 2];
    
    final movements = <Offset>[];
    final minLength = current.length < previous.length ? current.length : previous.length;
    
    for (int i = 0; i < minLength; i++) {
      final movement = current[i] - previous[i];
      movements.add(movement);
    }
    
    return movements;
  }

  /// Get the average position of all center points in the current frame
  Offset? getAveragePosition() {
    final current = getCurrentCenterPoints();
    if (current.isEmpty) return null;
    
    double totalX = 0;
    double totalY = 0;
    
    for (final point in current) {
      totalX += point.dx;
      totalY += point.dy;
    }
    
    return Offset(totalX / current.length, totalY / current.length);
  }

  /// Check if there are objects in a specific region of the screen
  /// region should be normalized coordinates (0.0 to 1.0)
  bool hasObjectsInRegion(Rect region) {
    final current = getCurrentCenterPoints();
    return current.any((point) => region.contains(point));
  }

  /// Get the number of objects in the current frame
  int getCurrentObjectCount() {
    return getCurrentCenterPoints().length;
  }

  /// Get the closest center point to a given position
  Offset? getClosestCenterPoint(Offset targetPosition) {
    final current = getCurrentCenterPoints();
    if (current.isEmpty) return null;
    
    Offset closest = current.first;
    double minDistance = (current.first - targetPosition).distance;
    
    for (final point in current.skip(1)) {
      final distance = (point - targetPosition).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closest = point;
      }
    }
    
    return closest;
  }

  /// Clear all tracking history
  void clear() {
    _centerPointHistory.clear();
  }

  /// Get debug information about the tracker state
  Map<String, dynamic> getDebugInfo() {
    return {
      'historyLength': _centerPointHistory.length,
      'maxHistoryLength': _maxHistoryLength,
      'currentObjectCount': getCurrentObjectCount(),
      'averagePosition': getAveragePosition(),
      'hasMovementData': _centerPointHistory.length >= 2,
    };
  }
}
