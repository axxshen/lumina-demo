import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'dart:math' as math;

/// Configuration class for depth estimation parameters
class DepthEstimationConfig {
  /// Camera focal length in pixels (fx for horizontal, fy for vertical)
  final double focalLengthX;
  final double focalLengthY;

  /// Image dimensions in pixels
  final double imageWidth;
  final double imageHeight;

  /// Real-world object size database (in meters)
  /// Maps object class names to their approximate real-world dimensions
  final Map<String, ObjectDimensions> objectSizeDatabase;

  /// Depth calculation method to use
  final DepthCalculationMethod method;

  /// Maximum reasonable depth in meters (for filtering outliers)
  final double maxDepth;

  /// Minimum reasonable depth in meters (for filtering outliers)
  final double minDepth;

  const DepthEstimationConfig({
    required this.focalLengthX,
    required this.focalLengthY,
    required this.imageWidth,
    required this.imageHeight,
    this.objectSizeDatabase = const {},
    this.method = DepthCalculationMethod.averageDimension,
    this.maxDepth = 50.0, // 50 meters max
    this.minDepth = 0.1, // 10 cm min
  });

  /// Create config with common mobile camera parameters
  factory DepthEstimationConfig.mobile({
    double imageWidth = 1920,
    double imageHeight = 1080,
    double fovDegrees = 70.0, // Typical mobile camera FOV
    Map<String, ObjectDimensions>? customObjectSizes,
  }) {
    // Calculate focal length from FOV
    final fovRadians = fovDegrees * math.pi / 180.0;
    final focalLength = (imageWidth / 2) / math.tan(fovRadians / 2);

    return DepthEstimationConfig(
      focalLengthX: focalLength,
      focalLengthY: focalLength,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      objectSizeDatabase: {
        ...defaultObjectSizes,
        if (customObjectSizes != null) ...customObjectSizes,
      },
    );
  }
}

/// Enumeration of different depth calculation methods
enum DepthCalculationMethod {
  /// Use width dimension for depth calculation
  width,

  /// Use height dimension for depth calculation
  height,

  /// Use average of width and height dimensions
  averageDimension,

  /// Use the larger dimension (more reliable for accuracy)
  maxDimension,

  /// Use the smaller dimension (more conservative estimate)
  minDimension,
}

/// Real-world dimensions of common objects
class ObjectDimensions {
  final double width; // meters
  final double height; // meters
  final double depth; // meters (optional, for 3D objects)

  const ObjectDimensions({
    required this.width,
    required this.height,
    this.depth = 0.0,
  });

  /// Get the dimension to use based on calculation method
  double getDimension(DepthCalculationMethod method) {
    switch (method) {
      case DepthCalculationMethod.width:
        return width;
      case DepthCalculationMethod.height:
        return height;
      case DepthCalculationMethod.averageDimension:
        return (width + height) / 2;
      case DepthCalculationMethod.maxDimension:
        return math.max(width, height);
      case DepthCalculationMethod.minDimension:
        return math.min(width, height);
    }
  }
}

/// Default object size database with 91 common objects
const Map<String, ObjectDimensions> defaultObjectSizes = {
  // People
  'person': ObjectDimensions(width: 0.3, height: 1.7),

  // Vehicles
  'bicycle': ObjectDimensions(width: 0.6, height: 1.1),
  'car': ObjectDimensions(width: 1.8, height: 1.5),
  'motorcycle': ObjectDimensions(width: 0.8, height: 1.2),
  'airplane': ObjectDimensions(width: 35.0, height: 12.0), // Small aircraft
  'bus': ObjectDimensions(width: 2.5, height: 3.5),
  'train': ObjectDimensions(width: 3.0, height: 4.0),
  'truck': ObjectDimensions(width: 2.5, height: 3.0),
  'boat': ObjectDimensions(width: 8.0, height: 3.0), // Small boat
  // Outdoor objects
  'traffic light': ObjectDimensions(width: 0.3, height: 0.9),
  'fire hydrant': ObjectDimensions(width: 0.4, height: 1.0),
  'street sign': ObjectDimensions(width: 0.6, height: 0.6),
  'stop sign': ObjectDimensions(width: 0.75, height: 0.75),
  'parking meter': ObjectDimensions(width: 0.2, height: 1.2),
  'bench': ObjectDimensions(width: 1.8, height: 0.8),

  // Animals
  'bird': ObjectDimensions(width: 0.15, height: 0.15),
  'cat': ObjectDimensions(width: 0.25, height: 0.25),
  'dog': ObjectDimensions(width: 0.3, height: 0.6),
  'horse': ObjectDimensions(width: 1.0, height: 1.6),
  'sheep': ObjectDimensions(width: 0.6, height: 0.8),
  'cow': ObjectDimensions(width: 1.5, height: 1.4),
  'elephant': ObjectDimensions(width: 2.5, height: 3.0),
  'bear': ObjectDimensions(width: 1.0, height: 1.2),
  'zebra': ObjectDimensions(width: 1.2, height: 1.4),
  'giraffe': ObjectDimensions(width: 1.5, height: 5.0),

  // Accessories
  'hat': ObjectDimensions(width: 0.25, height: 0.15),
  'backpack': ObjectDimensions(width: 0.35, height: 0.5),
  'umbrella': ObjectDimensions(width: 1.0, height: 0.8), // Open umbrella
  'shoe': ObjectDimensions(width: 0.12, height: 0.28),
  'eye glasses': ObjectDimensions(width: 0.14, height: 0.05),
  'handbag': ObjectDimensions(width: 0.35, height: 0.25),
  'tie': ObjectDimensions(width: 0.1, height: 1.4),
  'suitcase': ObjectDimensions(width: 0.6, height: 0.4),

  // Sports equipment
  'frisbee': ObjectDimensions(width: 0.27, height: 0.27),
  'skis': ObjectDimensions(width: 0.08, height: 1.7),
  'snowboard': ObjectDimensions(width: 0.3, height: 1.6),
  'sports ball': ObjectDimensions(width: 0.22, height: 0.22), // Soccer ball
  'kite': ObjectDimensions(width: 1.0, height: 1.0),
  'baseball bat': ObjectDimensions(width: 0.07, height: 1.07),
  'baseball glove': ObjectDimensions(width: 0.25, height: 0.3),
  'skateboard': ObjectDimensions(width: 0.2, height: 0.8),
  'surfboard': ObjectDimensions(width: 0.5, height: 2.7),
  'tennis racket': ObjectDimensions(width: 0.27, height: 0.68),

  // Kitchen items
  'bottle': ObjectDimensions(width: 0.07, height: 0.25),
  'plate': ObjectDimensions(width: 0.25, height: 0.25),
  'wine glass': ObjectDimensions(width: 0.08, height: 0.20),
  'cup': ObjectDimensions(width: 0.08, height: 0.10),
  'fork': ObjectDimensions(width: 0.02, height: 0.20),
  'knife': ObjectDimensions(width: 0.02, height: 0.25),
  'spoon': ObjectDimensions(width: 0.03, height: 0.18),
  'bowl': ObjectDimensions(width: 0.15, height: 0.08),

  // Food items
  'banana': ObjectDimensions(width: 0.03, height: 0.18),
  'apple': ObjectDimensions(width: 0.08, height: 0.08),
  'sandwich': ObjectDimensions(width: 0.12, height: 0.08),
  'orange': ObjectDimensions(width: 0.07, height: 0.07),
  'broccoli': ObjectDimensions(width: 0.12, height: 0.15),
  'carrot': ObjectDimensions(width: 0.03, height: 0.20),
  'hot dog': ObjectDimensions(width: 0.03, height: 0.15),
  'pizza': ObjectDimensions(width: 0.3, height: 0.3),
  'donut': ObjectDimensions(width: 0.09, height: 0.09),
  'cake': ObjectDimensions(width: 0.25, height: 0.15),

  // Furniture
  'chair': ObjectDimensions(width: 0.5, height: 0.8),
  'couch': ObjectDimensions(width: 2.0, height: 0.8),
  'potted plant': ObjectDimensions(width: 0.3, height: 0.6),
  'bed': ObjectDimensions(width: 1.5, height: 0.6),
  'mirror': ObjectDimensions(width: 0.6, height: 0.8),
  'dining table': ObjectDimensions(width: 1.5, height: 0.75),
  'window': ObjectDimensions(width: 1.2, height: 1.5),
  'desk': ObjectDimensions(width: 1.2, height: 0.75),
  'toilet': ObjectDimensions(width: 0.4, height: 0.8),
  'door': ObjectDimensions(width: 0.9, height: 2.0),

  // Electronics
  'tv': ObjectDimensions(width: 1.2, height: 0.7),
  'laptop': ObjectDimensions(width: 0.35, height: 0.25),
  'mouse': ObjectDimensions(width: 0.06, height: 0.11),
  'remote': ObjectDimensions(width: 0.05, height: 0.20),
  'keyboard': ObjectDimensions(width: 0.45, height: 0.15),
  'cell phone': ObjectDimensions(width: 0.07, height: 0.15),

  // Appliances
  'microwave': ObjectDimensions(width: 0.5, height: 0.3),
  'oven': ObjectDimensions(width: 0.6, height: 0.6),
  'toaster': ObjectDimensions(width: 0.3, height: 0.2),
  'sink': ObjectDimensions(width: 0.6, height: 0.2),
  'refrigerator': ObjectDimensions(width: 0.7, height: 1.8),
  'blender': ObjectDimensions(width: 0.2, height: 0.4),

  // Indoor items
  'book': ObjectDimensions(width: 0.15, height: 0.23),
  'clock': ObjectDimensions(width: 0.3, height: 0.3),
  'vase': ObjectDimensions(width: 0.15, height: 0.3),
  'scissors': ObjectDimensions(width: 0.02, height: 0.20),
  'teddy bear': ObjectDimensions(width: 0.3, height: 0.4),
  'hair drier': ObjectDimensions(width: 0.25, height: 0.2),
  'toothbrush': ObjectDimensions(width: 0.02, height: 0.18),
  'hair brush': ObjectDimensions(width: 0.08, height: 0.22),
};

/// Result of depth estimation for a single object
class DepthEstimationResult {
  final YOLOResult detection;
  final double estimatedDepth; // in meters
  final double confidence; // 0.0 to 1.0
  final String method; // Description of method used
  final bool isReliable; // Whether the estimate is considered reliable

  const DepthEstimationResult({
    required this.detection,
    required this.estimatedDepth,
    required this.confidence,
    required this.method,
    required this.isReliable,
  });

  /// Get depth formatted as a user-friendly string
  String getFormattedDepth() {
    if (estimatedDepth < 1.0) {
      return '${(estimatedDepth * 100).toStringAsFixed(0)}cm';
    } else if (estimatedDepth < 10.0) {
      return '${estimatedDepth.toStringAsFixed(1)}m';
    } else {
      return '${estimatedDepth.toStringAsFixed(0)}m';
    }
  }

  /// Get confidence level as descriptive text
  String getConfidenceLevel() {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    if (confidence >= 0.4) return 'Low';
    return 'Very Low';
  }
}

/// Advanced depth estimation service using monocular camera and object recognition
class DepthEstimationService extends ChangeNotifier {
  static final DepthEstimationService _instance =
      DepthEstimationService._internal();
  static DepthEstimationService get instance => _instance;

  DepthEstimationService._internal();

  DepthEstimationConfig _config = DepthEstimationConfig.mobile();
  List<DepthEstimationResult> _latestResults = [];
  bool _isEnabled = true;

  // Statistics tracking
  int _totalEstimations = 0;
  double _averageDepth = 0.0;
  final Map<String, int> _classStatistics = {};

  // Getters
  DepthEstimationConfig get config => _config;
  List<DepthEstimationResult> get latestResults => _latestResults;
  bool get isEnabled => _isEnabled;
  int get totalEstimations => _totalEstimations;
  double get averageDepth => _averageDepth;
  Map<String, int> get classStatistics => Map.unmodifiable(_classStatistics);

  /// Update the depth estimation configuration
  void updateConfig(DepthEstimationConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  /// Enable or disable depth estimation
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _latestResults.clear();
    }
    notifyListeners();
  }

  /// Estimate depth for all detections in a frame
  List<DepthEstimationResult> estimateDepthForDetections(
    List<YOLOResult> detections,
  ) {
    if (!_isEnabled || detections.isEmpty) {
      _latestResults = [];
      return _latestResults;
    }

    final results = <DepthEstimationResult>[];

    for (final detection in detections) {
      final result = _estimateDepthForSingleDetection(detection);
      if (result != null) {
        results.add(result);
        _updateStatistics(result);
      }
    }

    _latestResults = results;
    notifyListeners();

    return results;
  }

  /// Estimate depth for a single detection
  DepthEstimationResult? _estimateDepthForSingleDetection(
    YOLOResult detection,
  ) {
    final className = detection.className.toLowerCase();
    final objectDimensions = _config.objectSizeDatabase[className];

    if (objectDimensions == null) {
      // Fallback: Use average object size estimation
      return _estimateWithFallbackMethod(detection);
    }

    // Calculate bounding box dimensions in pixels
    final boundingBox = detection.boundingBox;
    final pixelWidth = boundingBox.width;
    final pixelHeight = boundingBox.height;

    if (pixelWidth <= 0 || pixelHeight <= 0) {
      return null; // Invalid bounding box
    }

    // Get real-world dimension based on method
    final realWorldSize = objectDimensions.getDimension(_config.method);

    // Calculate depth using pinhole camera model: Z = (f * W) / w
    double depth = 0.0;
    String methodDescription = '';

    switch (_config.method) {
      case DepthCalculationMethod.width:
        depth = (_config.focalLengthX * realWorldSize) / pixelWidth;
        methodDescription = 'Width-based';
        break;
      case DepthCalculationMethod.height:
        depth = (_config.focalLengthY * realWorldSize) / pixelHeight;
        methodDescription = 'Height-based';
        break;
      case DepthCalculationMethod.averageDimension:
        final depthX = (_config.focalLengthX * realWorldSize) / pixelWidth;
        final depthY = (_config.focalLengthY * realWorldSize) / pixelHeight;
        depth = (depthX + depthY) / 2;
        methodDescription = 'Average dimension';
        break;
      case DepthCalculationMethod.maxDimension:
        final depthX =
            (_config.focalLengthX * objectDimensions.width) / pixelWidth;
        final depthY =
            (_config.focalLengthY * objectDimensions.height) / pixelHeight;
        depth = math.max(depthX, depthY);
        methodDescription = 'Max dimension';
        break;
      case DepthCalculationMethod.minDimension:
        final depthX =
            (_config.focalLengthX * objectDimensions.width) / pixelWidth;
        final depthY =
            (_config.focalLengthY * objectDimensions.height) / pixelHeight;
        depth = math.min(depthX, depthY);
        methodDescription = 'Min dimension';
        break;
    }

    // Filter outliers
    if (depth < _config.minDepth || depth > _config.maxDepth) {
      return DepthEstimationResult(
        detection: detection,
        estimatedDepth: depth,
        confidence: 0.1,
        method: '$methodDescription (filtered)',
        isReliable: false,
      );
    }

    // Calculate confidence based on various factors
    final confidence = _calculateConfidence(
      detection,
      depth,
      pixelWidth,
      pixelHeight,
    );

    return DepthEstimationResult(
      detection: detection,
      estimatedDepth: depth,
      confidence: confidence,
      method: methodDescription,
      isReliable: confidence >= 0.4,
    );
  }

  /// Fallback depth estimation for unknown objects
  DepthEstimationResult? _estimateWithFallbackMethod(YOLOResult detection) {
    final boundingBox = detection.boundingBox;
    final pixelArea = boundingBox.width * boundingBox.height;

    if (pixelArea <= 0) return null;

    // Use empirical relationship between bounding box size and distance
    // This is a rough approximation and should be calibrated for your specific use case
    final normalizedArea =
        pixelArea / (_config.imageWidth * _config.imageHeight);

    // Logarithmic relationship: larger objects appear closer
    final depth = math.max(0.5, -5 * math.log(normalizedArea * 10));

    // Clamp to reasonable bounds
    final clampedDepth = math.max(
      _config.minDepth,
      math.min(_config.maxDepth, depth),
    );

    return DepthEstimationResult(
      detection: detection,
      estimatedDepth: clampedDepth,
      confidence: 0.3, // Lower confidence for unknown objects
      method: 'Area-based fallback',
      isReliable: false,
    );
  }

  /// Calculate confidence score for depth estimation
  double _calculateConfidence(
    YOLOResult detection,
    double depth,
    double pixelWidth,
    double pixelHeight,
  ) {
    double confidence = 0.5; // Base confidence

    // Factor 1: YOLO detection confidence
    confidence += detection.confidence * 0.3;

    // Factor 2: Bounding box size (larger boxes are generally more reliable)
    final normalizedArea =
        (pixelWidth * pixelHeight) / (_config.imageWidth * _config.imageHeight);
    if (normalizedArea > 0.01) confidence += 0.2; // Object is reasonably large
    if (normalizedArea > 0.05) confidence += 0.1; // Object is quite large

    // Factor 3: Aspect ratio reasonableness (objects shouldn't be extremely elongated)
    final aspectRatio = pixelWidth / pixelHeight;
    if (aspectRatio > 0.2 && aspectRatio < 5.0) confidence += 0.1;

    // Factor 4: Depth reasonableness
    if (depth > 0.5 && depth < 20.0)
      confidence += 0.1; // Reasonable distance range

    // Factor 5: Object class reliability (some objects are more predictable in size)
    final className = detection.className.toLowerCase();
    final highReliabilityClasses = ['person', 'car', 'chair', 'tv', 'laptop'];
    if (highReliabilityClasses.contains(className)) confidence += 0.1;

    return math.max(0.0, math.min(1.0, confidence));
  }

  /// Update internal statistics
  void _updateStatistics(DepthEstimationResult result) {
    _totalEstimations++;

    // Update average depth (running average)
    _averageDepth =
        (_averageDepth * (_totalEstimations - 1) + result.estimatedDepth) /
        _totalEstimations;

    // Update class statistics
    final className = result.detection.className;
    _classStatistics[className] = (_classStatistics[className] ?? 0) + 1;
  }

  /// Get depth result for a specific detection (by index)
  DepthEstimationResult? getDepthForDetection(int index) {
    if (index < 0 || index >= _latestResults.length) return null;
    return _latestResults[index];
  }

  /// Get depth result for the closest detection to a point
  DepthEstimationResult? getClosestDepthResult(Offset point) {
    if (_latestResults.isEmpty) return null;

    DepthEstimationResult? closest;
    double minDistance = double.infinity;

    for (final result in _latestResults) {
      final detection = result.detection;
      final centerX =
          (detection.normalizedBox.left + detection.normalizedBox.right) / 2;
      final centerY =
          (detection.normalizedBox.top + detection.normalizedBox.bottom) / 2;
      final center = Offset(centerX, centerY);

      final distance = (center - point).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closest = result;
      }
    }

    return closest;
  }

  /// Clear all statistics and results
  void clearStatistics() {
    _totalEstimations = 0;
    _averageDepth = 0.0;
    _classStatistics.clear();
    _latestResults.clear();
    debugPrint('DepthEstimationService: Statistics cleared');
    notifyListeners();
  }

  /// Get debug information about the service
  Map<String, dynamic> getDebugInfo() {
    return {
      'isEnabled': _isEnabled,
      'totalEstimations': _totalEstimations,
      'averageDepth': _averageDepth,
      'currentResults': _latestResults.length,
      'reliableResults': _latestResults.where((r) => r.isReliable).length,
      'configMethod': _config.method.toString(),
      'focalLength': _config.focalLengthX,
      'imageSize': '${_config.imageWidth}x${_config.imageHeight}',
      'objectDatabase': _config.objectSizeDatabase.length,
    };
  }
}
