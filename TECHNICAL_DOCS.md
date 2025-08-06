# Lumina Technical Documentation

**Complete implementation docs**

This comprehensive technical documentation provides detailed guidance for understanding and extending Lumina's implementation, including advanced AI integration, actual service architecture, and proven solutions.

## Table of Contents

- [Lumina Technical Documentation](#lumina-technical-documentation)
  - [Table of Contents](#table-of-contents)
  - [Architecture Overview](#architecture-overview)
  - [Flutter Gemma 3n Integration](#flutter-gemma-3n-integration)
    - [Core Implementation](#core-implementation)
  - [YOLO11n Object Detection Implementation](#yolo11n-object-detection-implementation)
    - [YOLO Service Implementation](#yolo-service-implementation)
    - [Model Types](#model-types)
  - [Depth Estimation Pipeline](#depth-estimation-pipeline)
    - [Depth Estimation Service](#depth-estimation-service)
  - [Speech Integration Architecture](#speech-integration-architecture)
    - [Text-to-Speech Service](#text-to-speech-service)
    - [Speech-to-Text Service](#speech-to-text-service)
  - [Obstacle Avoidance System](#obstacle-avoidance-system)
    - [Obstacle Avoidance Implementation](#obstacle-avoidance-implementation)
  - [Camera Service Implementation](#camera-service-implementation)
    - [Camera Service](#camera-service)
  - [State Management with Provider](#state-management-with-provider)
    - [Main App Structure](#main-app-structure)
  - [Common Development Challenges \& Solutions](#common-development-challenges--solutions)
    - [Challenge #1: Model Loading and Memory Management](#challenge-1-model-loading-and-memory-management)
    - [Challenge #2: Real-time Performance](#challenge-2-real-time-performance)
    - [Challenge #3: Speech Integration](#challenge-3-speech-integration)
    - [Challenge #4: Accessibility Features](#challenge-4-accessibility-features)

## Architecture Overview

Lumina employs a modular architecture using Provider pattern for state management:

```
┌─────────────────────────────────────────────┐
│                UI Layer                     │
│  ┌─────────────┐ ┌─────────────┐           │
│  │   Camera    │ │   Speech    │           │
│  │   Widget    │ │   Widget    │           │
│  └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│              Provider Services               │
│  ┌─────────┐ ┌─────────┐ ┌─────────────┐   │
│  │ Gemma   │ │ YOLO11n │ │   Depth     │   │
│  │Service  │ │ Service │ │ Estimation  │   │
│  └─────────┘ └─────────┘ └─────────────┘   │
│  ┌─────────┐ ┌─────────┐ ┌─────────────┐   │
│  │  TTS    │ │ Speech  │ │  Obstacle   │   │
│  │Service  │ │ Service │ │ Avoidance   │   │
│  └─────────┘ └─────────┘ └─────────────┘   │
└─────────────────────────────────────────────┘
```

## Flutter Gemma 3n Integration

### Core Implementation

The heart of Lumina's AI capabilities lies in the **Flutter Gemma 3n E2B** integration for on-device Visual Question Answering (VQA).

```dart
// services/gemma_service.dart - ACTUAL IMPLEMENTATION
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:camera/camera.dart';

class GemmaService extends ChangeNotifier {
  static GemmaService? _instance;
  static GemmaService get instance => _instance ??= GemmaService._();

  final _gemma = FlutterGemmaPlugin.instance;
  InferenceModel? _inferenceModel;
  InferenceModelSession? _session;
  bool _isModelLoaded = false;
  bool _isLoading = false;
  String? _error;
  String _loadingStatus = '';

  bool get isModelLoaded => _isModelLoaded;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get loadingStatus => _loadingStatus;
  bool get isReady => _isModelLoaded && _session != null;

  /// Initialize Gemma with model download and loading
  Future<bool> initialize({
    Function(double progress)? onProgress,
    Function(String message)? onStatusUpdate,
  }) async {
    if (_isLoading || _isModelLoaded) return _isModelLoaded;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final modelManager = _gemma.modelManager;
      final url = "https://huggingface.co/aoshendev/gemma-3n-e2b-it-int4/resolve/main/gemma-3n-E2B-it-int4.task";

      // Check if model is already installed
      onStatusUpdate?.call("🔍 Checking model installation...");

      if (!await modelManager.isModelInstalled) {
        onStatusUpdate?.call("📥 Downloading model...");

        // Download model with progress tracking
        await for (var progress
            in modelManager.downloadModelFromNetworkWithProgress(url)) {
          onProgress?.call(progress / 100.0);
          onStatusUpdate?.call(
            "📥 Downloading model: ${progress.toStringAsFixed(1)}%",
          );
        }
      }

      // Load the model with multimodal support
      onStatusUpdate?.call("🔄 Loading model...");
      _inferenceModel = await _gemma.createModel(
        modelType: ModelType.gemmaIt, // Gemma 3 Nano E2B uses gemmaIt type
        preferredBackend: PreferredBackend.gpuFloat16, // Use GPU for better performance
        maxTokens: 4096,
        supportImage: true, // Enable image support
        maxNumImages: 1, // Single image support
      );

      // Create session with multimodal support
      _session = await _inferenceModel!.createSession(
        temperature: 1.0,
        randomSeed: 1,
        topK: 1,
        enableVisionModality: true,
      );
      
      _loadingStatus = "Ready!";
      _isModelLoaded = true;
      onStatusUpdate?.call("Gemma 3n is ready!");
      return true;
    } catch (e) {
      _error = "Failed to initialize Gemma: $e";
      onStatusUpdate?.call("❌ Initialization failed: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send multimodal query with both image and text
  Future<String> sendMultiModalQuery(CameraImage? image, String text) async {
    if (!_isModelLoaded || _session == null) {
      return "Model not loaded yet. Please wait...";
    }

    try {
      Message message;

      if (image != null) {
        // Convert CameraImage to optimized 256x256 format
        final imageBytes = await _convertImageToPngOptimized(image, 256, 256);

        if (imageBytes != null) {
          final prompt = text.isNotEmpty
              ? text
              : "Please describe what you see in this image. And respond to the user query if any. Keep the response concise and relevant within 3 short sentences without markdown formatting.";

          final instruction = "Keep the response concise and relevant without unnecessary details.";
          final fullPrompt = "$prompt $instruction";

          message = Message.withImage(
            text: fullPrompt,
            imageBytes: imageBytes,
            isUser: true,
          );
        } else {
          message = Message.text(text: text, isUser: true);
        }
      } else {
        message = Message.text(text: text, isUser: true);
      }

      await _session!.addQueryChunk(message);
      return await _session!.getResponse();
    } catch (e) {
      return "Sorry, I encountered an error processing your request: $e";
    }
  }

  /// Stream-based multimodal query for real-time responses
  Stream<String> sendMultiModalQueryStream(CameraImage? image, String text) async* {
    if (!_isModelLoaded || _session == null) {
      yield "Model not loaded yet. Please wait...";
      return;
    }

    try {
      Message message;

      if (image != null) {
        final imageBytes = await _convertImageToPngOptimized(image, 256, 256);
        // Build message with image and text...
      }

      await _session!.addQueryChunk(message);
      
      // Stream the response chunks
      await for (final chunk in _session!.getResponseAsync()) {
        yield chunk;
      }
    } catch (e) {
      yield "Error: $e";
    }
  }
}
```

## YOLO11n Object Detection Implementation

### YOLO Service Implementation

```dart
// services/yolo_service.dart - ACTUAL IMPLEMENTATION
import 'package:ultralytics_yolo/yolo_result.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import '../models/model_type.dart';

class YOLOService extends ChangeNotifier {
  static final YOLOService _instance = YOLOService._internal();
  static YOLOService get instance => _instance;

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

  // Detection thresholds
  final double _confidenceThreshold = 0.22;
  final double _iouThreshold = 0.45;
  final int _numItemsThreshold = 30;

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

  /// Initialize YOLO service
  Future<void> initialize() async {
    _modelManager = ModelManager();
    await _modelManager.initialize();
    await loadModel(_selectedModel);
  }

  /// Load YOLO model
  Future<void> loadModel(ModelType modelType) async {
    if (_isModelLoading) return;

    _selectedModel = modelType;
    _isModelLoading = true;
    _loadingMessage = 'Loading ${modelType.modelName}...';
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final modelPath = await _modelManager.getModelPath(_selectedModel);

      _modelPath = modelPath;
      _isModelLoading = false;
      _loadingMessage = '';
      _downloadProgress = 0.0;

      if (modelPath != null) {
        // Set detection thresholds
        await _yoloController.setThresholds(
          confidenceThreshold: _confidenceThreshold,
          iouThreshold: _iouThreshold,
          numItemsThreshold: _numItemsThreshold,
        );
      }

      notifyListeners();
    } catch (e) {
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
}
```

### Model Types

```dart
// models/model_type.dart - ACTUAL IMPLEMENTATION
import 'package:ultralytics_yolo/yolo_task.dart';

enum ModelType {
  /// Object detection model
  detect('yolo11n', YOLOTask.detect),

  /// Instance segmentation model
  segment('yolo11n-seg', YOLOTask.segment),

  /// Image classification model
  classify('yolo11n-cls', YOLOTask.classify),

  /// Pose estimation model
  pose('yolo11n-pose', YOLOTask.pose),

  /// Oriented bounding box detection model
  obb('yolo11n-obb', YOLOTask.obb);

  final String modelName;
  final YOLOTask task;

  const ModelType(this.modelName, this.task);
}
```

## Depth Estimation Pipeline

### Depth Estimation Service

```dart
// services/depth_estimation_service.dart - ACTUAL IMPLEMENTATION
import 'package:ultralytics_yolo/yolo_result.dart';
import 'dart:math' as math;

class DepthEstimationService extends ChangeNotifier {
  static final DepthEstimationService _instance = DepthEstimationService._internal();
  static DepthEstimationService get instance => _instance;

  DepthEstimationService._internal();

  // Configuration
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

  /// Initialize depth estimation service
  Future<void> initialize([DepthEstimationConfig? config]) async {
    if (config != null) {
      _config = config;
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
        final depthX = (_config.focalLengthX * objectDimensions.width) / pixelWidth;
        final depthY = (_config.focalLengthY * objectDimensions.height) / pixelHeight;
        depth = math.max(depthX, depthY);
        methodDescription = 'Max dimension';
        break;
      case DepthCalculationMethod.minDimension:
        final depthX = (_config.focalLengthX * objectDimensions.width) / pixelWidth;
        final depthY = (_config.focalLengthY * objectDimensions.height) / pixelHeight;
        depth = math.min(depthX, depthY);
        methodDescription = 'Min dimension';
        break;
    }

    // Filter outliers and return DepthEstimationResult
    if (depth < _config.minDepth || depth > _config.maxDepth) {
      return DepthEstimationResult(
        detection: detection,
        estimatedDepth: depth,
        confidence: 0.1,
        method: '$methodDescription (filtered)',
        isReliable: false,
      );
    }

    // Calculate confidence and return result
    final confidence = _calculateConfidence(detection, depth);
    return DepthEstimationResult(
      detection: detection,
      estimatedDepth: depth,
      confidence: confidence,
      method: methodDescription,
      isReliable: confidence > 0.7,
    );
  }
}

/// Configuration for depth estimation
class DepthEstimationConfig {
  final double focalLengthX;
  final double focalLengthY;
  final double imageWidth;
  final double imageHeight;
  final Map<String, ObjectDimensions> objectSizeDatabase;
  final DepthCalculationMethod method;
  final double maxDepth;
  final double minDepth;

  const DepthEstimationConfig({
    required this.focalLengthX,
    required this.focalLengthY,
    required this.imageWidth,
    required this.imageHeight,
    this.objectSizeDatabase = const {},
    this.method = DepthCalculationMethod.averageDimension,
    this.maxDepth = 50.0,
    this.minDepth = 0.1,
  });

  /// Create config with common mobile camera parameters
  factory DepthEstimationConfig.mobile({
    double imageWidth = 1920,
    double imageHeight = 1080,
    double fovDegrees = 70.0,
    Map<String, ObjectDimensions>? customObjectSizes,
  }) {
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

enum DepthCalculationMethod {
  width,
  height,
  averageDimension,
  maxDimension,
  minDimension,
}

class ObjectDimensions {
  final double width;
  final double height;
  final double depth;

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
}
```

## Speech Integration Architecture

### Text-to-Speech Service

```dart
// services/TTSService.dart - ACTUAL IMPLEMENTATION
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:io';

class TTSService extends ChangeNotifier {
  late FlutterTts flutterTts;
  bool _isSpeaking = false;
  final List<String> _speakQueue = [];
  String _streamBuffer = '';
  Timer? _bufferTimer;
  bool _isStreaming = false;

  // Enhanced streaming variables
  final int _minChunkLength = 15;
  final int _maxBufferLength = 50;
  final bool _canStartEarly = true;
  
  // Store original TTS settings
  double _originalSpeechRate = 0.5;
  double _originalPitch = 1.0;
  double _originalVolume = 1.0;

  TTSService() {
    flutterTts = FlutterTts();
    _initTts();
  }

  _initTts() async {
    try {
      // Configure iOS audio session to play even in silent mode
      if (Platform.isIOS) {
        await flutterTts.setSharedInstance(true);
        await flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      }

      await flutterTts.setLanguage("en-US");
      _originalSpeechRate = 0.5;
      _originalPitch = 1.0;
      _originalVolume = 1.0;
      await flutterTts.setSpeechRate(_originalSpeechRate);
      await flutterTts.setVolume(_originalVolume);
      await flutterTts.setPitch(_originalPitch);

      // Set up completion handler
      flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isSpeaking && _speakQueue.isNotEmpty) {
            _processQueue();
          }
        });
      });

      // Set up error handler
      flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isSpeaking && _speakQueue.isNotEmpty) {
            _processQueue();
          }
        });
      });

      await flutterTts.stop();
    } catch (e) {
      debugPrint("[TTS] Initialization error: $e");
    }
  }

  /// Speak complete text (sentence by sentence)
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    _speakQueue.addAll(sentences.where((s) => s.trim().isNotEmpty));

    if (!_isSpeaking) {
      await _processQueue();
    }
  }

  /// Start streaming mode for real-time text
  void startStreaming() {
    _isStreaming = true;
    _streamBuffer = '';
    notifyListeners();
  }

  /// Add chunk of text to streaming buffer
  void addStreamingText(String chunk) {
    if (!_isStreaming) return;

    _streamBuffer += chunk;
    
    // Reset or start the buffer timer
    _bufferTimer?.cancel();
    _bufferTimer = Timer(const Duration(milliseconds: 300), () {
      _processStreamBuffer();
    });

    // Check if we should speak immediately
    if (_shouldSpeakNow()) {
      _bufferTimer?.cancel();
      _processStreamBuffer();
    }
  }

  bool _shouldSpeakNow() {
    return _streamBuffer.length >= _maxBufferLength ||
           _streamBuffer.contains('.') ||
           _streamBuffer.contains('!') ||
           _streamBuffer.contains('?');
  }

  void _processStreamBuffer() {
    if (_streamBuffer.trim().isEmpty) return;

    final textToSpeak = _streamBuffer.trim();
    _streamBuffer = '';
    
    _speakQueue.add(textToSpeak);
    
    if (!_isSpeaking) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_speakQueue.isEmpty || _isSpeaking) return;

    _isSpeaking = true;
    final text = _speakQueue.removeAt(0);
    
    try {
      await flutterTts.speak(text);
    } catch (e) {
      _isSpeaking = false;
    }
    
    notifyListeners();
  }

  /// Stop streaming and clear buffers
  void stopStreaming() {
    _isStreaming = false;
    _bufferTimer?.cancel();
    _streamBuffer = '';
    notifyListeners();
  }

  /// Reset TTS state for new session
  Future<void> resetForNewSession() async {
    await flutterTts.stop();
    _speakQueue.clear();
    _streamBuffer = '';
    _isSpeaking = false;
    _bufferTimer?.cancel();
    notifyListeners();
  }
}
```

### Speech-to-Text Service

```dart
// services/SpeechService.dart - ACTUAL IMPLEMENTATION
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;

  Future<void> initialize() async {
    await _requestPermissions();
    await _speech.initialize();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.microphone.isDenied) {
      await Permission.microphone.request();
    }
    if (await Permission.speech.isDenied) {
      await Permission.speech.request();
    }
  }

  void startListening() {
    if (!_isListening) {
      _recognizedText = '';
      _speech.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          notifyListeners();
        },
        listenFor: const Duration(hours: 1), // Very long duration - essentially unlimited
        pauseFor: const Duration(hours: 1), // Very long pause duration - prevent auto-stop
        listenOptions: stt.SpeechListenOptions(
          partialResults: true, // Enable real-time transcription
          cancelOnError: true, // Cancel on error
          onDevice: false, // Use server-based recognition for better continuous listening
        ),
      );
      _isListening = true;
      notifyListeners();
    }
  }

  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  void clearText() {
    _recognizedText = '';
    notifyListeners();
  }
}
```

## Obstacle Avoidance System

### Obstacle Avoidance Implementation

```dart
// services/obstacle_avoidance_service.dart - ACTUAL IMPLEMENTATION
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultralytics_yolo/yolo_result.dart';
import 'depth_estimation_service.dart';

class ObstacleAvoidanceService extends ChangeNotifier {
  static final ObstacleAvoidanceService _instance = ObstacleAvoidanceService._internal();
  static ObstacleAvoidanceService get instance => _instance;

  // Service state
  bool _isEnabled = false;
  bool _isInitialized = false;

  // Grid configuration (3x3)
  static const int gridSize = 3;
  static const int totalGridCells = gridSize * gridSize;

  // Distance thresholds (in meters)
  static const double safetyThreshold = 1.0;
  static const double warningThreshold = 0.5;

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

    await _loadSettings();
    _isInitialized = true;
    notifyListeners();
  }

  /// Load settings from shared preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('enable_obstacle_avoidance') ?? false;
    } catch (e) {
      _isEnabled = false;
    }
  }

  /// Enable or disable obstacle avoidance
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_obstacle_avoidance', enabled);
    } catch (e) {
      debugPrint('Error saving obstacle avoidance setting: $e');
    }

    if (!enabled) {
      _obstacleGrid = List.generate(totalGridCells, (_) => false);
      _isCentralColumnClear = true;
    }

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
      final depth = depthService.getDepthForDetection(i);

      if (depth != null && depth <= safetyThreshold) {
        _processObstacleDetection(detection, depth);
      }
    }

    // Check central column (path ahead)
    _isCentralColumnClear = !(_obstacleGrid[1] || _obstacleGrid[4] || _obstacleGrid[7]);

    // Provide haptic feedback if obstacles detected
    _provideFeedback();

    notifyListeners();
  }

  void _processObstacleDetection(YOLOResult detection, double depth) {
    final boundingBox = detection.boundingBox;
    final centerX = (boundingBox.left + boundingBox.right) / 2;
    final centerY = (boundingBox.top + boundingBox.bottom) / 2;

    // Map detection to 3x3 grid
    final gridX = (centerX * gridSize).floor().clamp(0, gridSize - 1);
    final gridY = (centerY * gridSize).floor().clamp(0, gridSize - 1);
    final gridIndex = gridY * gridSize + gridX;

    _obstacleGrid[gridIndex] = true;
  }

  void _provideFeedback() {
    final now = DateTime.now();

    // Haptic feedback for obstacles
    if (_obstacleGrid.any((hasObstacle) => hasObstacle)) {
      if (now.difference(_lastVibrationTime) >= vibrationCooldown) {
        HapticFeedback.mediumImpact();
        _lastVibrationTime = now;
      }
    }
  }

  /// Get grid cell position (for UI overlay)
  bool isObstacleAt(int row, int col) {
    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) {
      return false;
    }
    final index = row * gridSize + col;
    return _obstacleGrid[index];
  }
}
```

## Camera Service Implementation

### Camera Service

```dart
// services/CameraService.dart - ACTUAL IMPLEMENTATION
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService extends ChangeNotifier {
  CameraController? _cameraController;
  bool _isReady = false;
  CameraImage? _latestImage;
  bool _isProcessing = false;
  
  CameraController? get cameraController => _cameraController;
  bool get isReady => _isReady;
  CameraImage? get latestImage => _latestImage;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium, // Optimized for performance
        enableAudio: false,
      );
      await _cameraController!.initialize();
      _isReady = true;
      notifyListeners();
      _startImageStream();
    }
  }

  void _startImageStream() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isProcessing) {
          _latestImage = image;
        }
      });
    }
  }
  
  void setProcessing(bool processing) {
    _isProcessing = processing;
  }
  
  void clearLatestImage() {
    _latestImage = null;
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }
}
```

## State Management with Provider

### Main App Structure

```dart
// main.dart - ACTUAL IMPLEMENTATION
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hide system UI for immersive experience
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [], // Completely hide status bar and navigation bar
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraService()),
        ChangeNotifierProvider(create: (_) => SpeechService()),
        ChangeNotifierProvider(create: (_) => TTSService()),
        ChangeNotifierProvider(create: (_) => GemmaService.instance),
        ChangeNotifierProvider(create: (_) => YOLOService.instance),
        ChangeNotifierProvider(create: (_) => DepthEstimationService.instance),
        ChangeNotifierProvider(create: (_) => ObstacleAvoidanceService.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.black,
        ),
        initialRoute: '/setup',
        routes: {
          '/setup': (context) => const ModelSetupScreen(),
          '/home': (context) => const CameraApp(),
        },
      ),
    );
  }
}
```

## Common Development Challenges & Solutions

### Challenge #1: Model Loading and Memory Management

**Real Implementation Approach**:
- Gemma 3n E2B model is downloaded from HuggingFace
- Memory optimization through image resizing (256x256)
- Lazy loading with progress callbacks
- Error handling with user feedback

### Challenge #2: Real-time Performance

**Actual Solutions**:
- YOLO11n models for fast inference
- Camera image stream with processing flags
- FPS monitoring and optimization
- Efficient Provider state management

### Challenge #3: Speech Integration

**Real Implementation**:
- Streaming TTS with buffer management
- Continuous speech recognition with long timeouts
- Platform-specific audio session configuration
- Queue-based speech processing

### Challenge #4: Accessibility Features

**Actual Implementation**:
- Haptic feedback for obstacle detection
- Audio cues for navigation
- 3x3 grid-based spatial awareness
- Immersive UI with hidden system bars

