import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'depth_estimation_service.dart';

/// Obstacle avoidance service providing haptic feedback and audio alerts
class ObstacleAvoidanceService extends ChangeNotifier {
  static final ObstacleAvoidanceService _instance =
      ObstacleAvoidanceService._internal();
  static ObstacleAvoidanceService get instance => _instance;

  ObstacleAvoidanceService._internal();

  // Service state
  bool _isEnabled = false;
  bool _isInitialized = false;

  // Grid configuration (3x3)
  static const int gridSize = 3;
  static const int totalGridCells = gridSize * gridSize;

  // Distance thresholds (in meters)
  static const double safetyThreshold = 1.0; // 1 meter
  static const double warningThreshold = 0.5; // 0.5 meters

  // Timing control for feedback
  DateTime _lastVibrationTime = DateTime.now();
  DateTime _lastSafeAudioTime = DateTime.now();
  static const Duration vibrationCooldown = Duration(milliseconds: 500);
  static const Duration safeAudioCooldown = Duration(seconds: 3);

  // Current obstacle state
  List<bool> _obstacleGrid = List.generate(totalGridCells, (_) => false);
  bool _isCentralColumnClear = true;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  List<bool> get obstacleGrid => List.unmodifiable(_obstacleGrid);
  bool get isCentralColumnClear => _isCentralColumnClear;

  /// Initialize the obstacle avoidance service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('ObstacleAvoidanceService: Initializing...');

    // Load settings
    await _loadSettings();

    _isInitialized = true;
    debugPrint('ObstacleAvoidanceService: Initialized. Enabled: $_isEnabled');
    notifyListeners();
  }

  /// Load settings from shared preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('enable_obstacle_avoidance') ?? false;
    } catch (e) {
      debugPrint('ObstacleAvoidanceService: Error loading settings: $e');
      _isEnabled = false;
    }
  }

  /// Enable or disable obstacle avoidance
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;

    // Save to preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_obstacle_avoidance', enabled);
    } catch (e) {
      debugPrint('ObstacleAvoidanceService: Error saving settings: $e');
    }

    if (!enabled) {
      // Clear obstacle grid when disabled
      _obstacleGrid = List.generate(totalGridCells, (_) => false);
      _isCentralColumnClear = true;
    }

    debugPrint('ObstacleAvoidanceService: ${enabled ? 'Enabled' : 'Disabled'}');
    notifyListeners();
  }

  /// Process detections for obstacle avoidance
  void processDetections(
    List<YOLOResult> detections,
    DepthEstimationService depthService,
  ) {
    if (!_isEnabled || !_isInitialized) return;

    // Reset obstacle grid
    _obstacleGrid = List.generate(totalGridCells, (_) => false);

    // Process each detection
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      final depthResult = depthService.getDepthForDetection(i);

      if (depthResult == null) continue;

      final depth = depthResult.estimatedDepth;

      // Only process objects within safety threshold
      if (depth < safetyThreshold) {
        final gridIndex = _calculateGridIndex(detection);
        if (gridIndex >= 0 && gridIndex < totalGridCells) {
          _obstacleGrid[gridIndex] = true;

          // Trigger vibration based on distance
          _triggerVibration(depth);
        }
      }
    }

    // Check if central column is clear
    _updateCentralColumnStatus();

    notifyListeners();
  }

  /// Calculate which grid cell a detection belongs to
  int _calculateGridIndex(YOLOResult detection) {
    try {
      final boundingBox = detection.boundingBox;
      final centerX = (boundingBox.left + boundingBox.right) / 2;
      final centerY = (boundingBox.top + boundingBox.bottom) / 2;

      // Assume screen dimensions (these should ideally be passed in)
      const screenWidth = 1000.0; // Adjust based on your app
      const screenHeight = 1000.0; // Adjust based on your app

      final cellWidth = screenWidth / gridSize;
      final cellHeight = screenHeight / gridSize;

      final col = (centerX / cellWidth).floor().clamp(0, gridSize - 1);
      final row = (centerY / cellHeight).floor().clamp(0, gridSize - 1);

      return row * gridSize + col;
    } catch (e) {
      debugPrint('ObstacleAvoidanceService: Error calculating grid index: $e');
      return -1;
    }
  }

  /// Update the status of the central column
  void _updateCentralColumnStatus() {
    // Central column indices: 1, 4, 7 (middle column in 3x3 grid)
    const centralColumnIndices = [1, 4, 7];

    _isCentralColumnClear = !centralColumnIndices.any(
      (index) => _obstacleGrid[index],
    );
  }

  /// Trigger haptic vibration based on distance
  void _triggerVibration(double depth) {
    final now = DateTime.now();

    // Check cooldown
    if (now.difference(_lastVibrationTime) < vibrationCooldown) {
      return;
    }

    try {
      if (depth < warningThreshold) {
        // Strong vibration for close objects
        HapticFeedback.heavyImpact();
        debugPrint(
          'ObstacleAvoidanceService: Strong vibration (${depth.toStringAsFixed(1)}m)',
        );
      } else {
        // Light vibration for distant objects
        HapticFeedback.lightImpact();
        debugPrint(
          'ObstacleAvoidanceService: Light vibration (${depth.toStringAsFixed(1)}m)',
        );
      }

      _lastVibrationTime = now;
    } catch (e) {
      debugPrint('ObstacleAvoidanceService: Error triggering vibration: $e');
    }
  }


  /// Get obstacle status for a specific grid cell
  bool isObstacleInCell(int row, int col) {
    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) {
      return false;
    }

    final index = row * gridSize + col;
    return _obstacleGrid[index];
  }

  /// Get a visual representation of the obstacle grid
  String getGridVisualization() {
    final buffer = StringBuffer();

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final index = row * gridSize + col;
        buffer.write(_obstacleGrid[index] ? 'X' : '.');
        buffer.write(' ');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Clear all obstacle data
  void clearObstacles() {
    _obstacleGrid = List.generate(totalGridCells, (_) => false);
    _isCentralColumnClear = true;
    notifyListeners();
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'isEnabled': _isEnabled,
      'isInitialized': _isInitialized,
      'isCentralColumnClear': _isCentralColumnClear,
      'obstacleCount': _obstacleGrid.where((obstacle) => obstacle).length,
      'gridVisualization': getGridVisualization(),
      'safetyThreshold': '${safetyThreshold}m',
      'warningThreshold': '${warningThreshold}m',
    };
  }

  @override
  void dispose() {
    debugPrint('ObstacleAvoidanceService: Disposing...');
    super.dispose();
  }
}
