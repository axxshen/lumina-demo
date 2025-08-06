import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import '../models/model_type.dart';
import 'model_manager.dart';
import 'depth_estimation_service.dart';
import 'obstacle_avoidance_service.dart';

/// Service for managing YOLO object detection
class YOLOService extends ChangeNotifier {
  static final YOLOService _instance = YOLOService._internal();
  static YOLOService get instance => _instance;

  YOLOService._internal();

  // YOLO controller for managing detection settings
  final YOLOViewController _yoloController = YOLOViewController();
  YOLOViewController get yoloController => _yoloController;

  // Model manager for handling model downloads
  late final ModelManager _modelManager;

  // Current state
  bool _isModelLoading = false;
  String? _modelPath;
  String _loadingMessage = '';
  double _downloadProgress = 0.0;
  ModelType _selectedModel = ModelType.detect;

  // Detection results
  List<YOLOResult> _detectionResults = [];
  int _detectionCount = 0;
  double _currentFps = 0.0;

  // Depth estimation integration
  late final DepthEstimationService _depthService;
  
  // Obstacle avoidance integration
  ObstacleAvoidanceService? _obstacleAvoidanceService;

  // Getters
  bool get isModelLoading => _isModelLoading;
  String? get modelPath => _modelPath;
  String get loadingMessage => _loadingMessage;
  double get downloadProgress => _downloadProgress;
  ModelType get selectedModel => _selectedModel;
  List<YOLOResult> get detectionResults => _detectionResults;
  int get detectionCount => _detectionCount;
  double get currentFps => _currentFps;
  bool get isReady => _modelPath != null && !_isModelLoading;
  DepthEstimationService get depthService => _depthService;
  ObstacleAvoidanceService? get obstacleAvoidanceService => _obstacleAvoidanceService;

  // Detection settings with fixed values for simplicity
  final double _confidenceThreshold = 0.22; // 0.5 default
  final double _iouThreshold = 0.45;
  final int _numItemsThreshold = 30;

  double get confidenceThreshold => _confidenceThreshold;
  double get iouThreshold => _iouThreshold;
  int get numItemsThreshold => _numItemsThreshold;

  /// Initialize the YOLO service
  Future<void> initialize() async {
    // Initialize ModelManager
    _modelManager = ModelManager(
      onDownloadProgress: (progress) {
        _downloadProgress = progress;
        notifyListeners();
      },
      onStatusUpdate: (message) {
        _loadingMessage = message;
        notifyListeners();
      },
    );

    // Initialize DepthEstimationService
    _depthService = DepthEstimationService.instance;
    
    // Initialize ObstacleAvoidanceService
    _obstacleAvoidanceService = ObstacleAvoidanceService.instance;
    await _obstacleAvoidanceService?.initialize();

    // Load initial model
    await _loadModel();
  }

  /// Load the YOLO model
  Future<void> _loadModel() async {
    _isModelLoading = true;
    _loadingMessage = 'Loading ${_selectedModel.modelName} model...';
    _downloadProgress = 0.0;
    _detectionCount = 0;
    _currentFps = 0.0;
    notifyListeners();

    try {
      // Use ModelManager to get the model path
      final modelPath = await _modelManager.getModelPath(_selectedModel);

      _modelPath = modelPath;
      _isModelLoading = false;
      _loadingMessage = '';
      _downloadProgress = 0.0;

      if (modelPath != null) {
        debugPrint('YOLOService: Model path set to: $modelPath');

        // Set initial thresholds
        await _yoloController.setThresholds(
          confidenceThreshold: _confidenceThreshold,
          iouThreshold: _iouThreshold,
          numItemsThreshold: _numItemsThreshold,
        );
      } else {
        debugPrint('YOLOService: Failed to load model');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('YOLOService: Error loading model: $e');
      _isModelLoading = false;
      _loadingMessage = 'Failed to load model';
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  /// Handle detection results from YOLO
void onDetectionResults(List<YOLOResult> results) {
    _detectionResults = results;
    _detectionCount = results.length;

    // Estimate depth for all detections
    _depthService.estimateDepthForDetections(results);

    notifyListeners();

    // Process obstacle avoidance logic
    _obstacleAvoidanceService?.processDetections(results, _depthService);
  }


  /// Handle performance metrics from YOLO
  void onPerformanceMetrics(dynamic metrics) {
    if (metrics.fps != null) {
      _currentFps = metrics.fps;
      notifyListeners();
    }
  }

  /// Calculate the center point of a detection bounding box in pixel coordinates
  ///
  /// Returns an Offset representing the center point in absolute pixel coordinates
  /// based on the detection's boundingBox property.
  Offset getCenterPoint(YOLOResult detection) {
    final box = detection.boundingBox;
    final centerX = (box.left + box.right) / 2;
    final centerY = (box.top + box.bottom) / 2;
    return Offset(centerX, centerY);
  }

  /// Calculate the center point of a detection bounding box in normalized coordinates
  ///
  /// Returns an Offset representing the center point in normalized coordinates (0.0 to 1.0)
  /// based on the detection's normalizedBox property. This is useful for screen-independent
  /// calculations and UI overlay positioning.
  Offset getNormalizedCenterPoint(YOLOResult detection) {
    final box = detection.normalizedBox;
    final centerX = (box.left + box.right) / 2;
    final centerY = (box.top + box.bottom) / 2;
    return Offset(centerX, centerY);
  }

  /// Get center points for all current detections in pixel coordinates
  ///
  /// Returns a list of Offset objects representing the center points of all
  /// currently detected objects in absolute pixel coordinates.
  List<Offset> getAllCenterPoints() {
    return _detectionResults
        .map((detection) => getCenterPoint(detection))
        .toList();
  }

  /// Get center points for all current detections in normalized coordinates
  ///
  /// Returns a list of Offset objects representing the center points of all
  /// currently detected objects in normalized coordinates (0.0 to 1.0).
  List<Offset> getAllNormalizedCenterPoints() {
    return _detectionResults
        .map((detection) => getNormalizedCenterPoint(detection))
        .toList();
  }

  @override
  void dispose() {
    debugPrint('YOLOService: Disposing...');
    super.dispose();
  }
}
