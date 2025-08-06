import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class GemmaService extends ChangeNotifier {
  static GemmaService? _instance;
  static GemmaService get instance => _instance ??= GemmaService._();

  GemmaService._();

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
      final url =
          "https://huggingface.co/aoshendev/gemma-3n-e2b-it-int4/resolve/main/gemma-3n-E2B-it-int4.task";

      // Step 1: Check if model is already installed
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

        onStatusUpdate?.call("✅ Model downloaded successfully!");
      } else {
        onStatusUpdate?.call("✅ Model already installed");
      }

      // Step 2: Set model path
      final documentsDir = await getApplicationDocumentsDirectory();
      final modelPath = '${documentsDir.path}/gemma-3n-E2B-it-int4.task';

      if (!await modelManager.isModelInstalled) {
        await modelManager.setModelPath(modelPath);
      }

      // Step 3: Create model instance
      _loadingStatus = "Initializing model engine...";
      onStatusUpdate?.call("Initializing model engine...");
      notifyListeners();

      _inferenceModel = await _gemma.createModel(
        modelType: ModelType.gemmaIt, // Gemma 3 Nano E2B uses gemmaIt type
        preferredBackend:
            PreferredBackend.gpuFloat16, // Use GPU for better performance
        maxTokens: 4096, // Use flutter_gemma example settings
        supportImage: true, // Enable image support
        maxNumImages: 1, // Single image support
        //potentially would increase amount of memory delegated to the model
      );

      debugPrint("Model engine initialized successfully");

      // Step 4: Create session instance with vision support
      _loadingStatus = "Setting up session interface...";
      onStatusUpdate?.call("Setting up session interface...");
      notifyListeners();

      _session = await _inferenceModel!.createSession(
        temperature: 1.0,
        randomSeed: 1,
        topK: 1,
        enableVisionModality: true, // Enable multimodal support
      );
      _loadingStatus = "Ready!";
      _isModelLoaded = true;
      onStatusUpdate?.call("Gemma 3n is ready!");
      debugPrint(
        "Gemma 3 Nano E2B model loaded successfully with multimodal support",
      );
      return true;
    } catch (e) {
      _error = "Failed to initialize Gemma: $e";
      onStatusUpdate?.call("❌ Initialization failed: $e");
      debugPrint(_error!);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load the Gemma 3 Nano model - deprecated, use initialize() instead
  @Deprecated('Use initialize() instead')
  Future<void> loadModel() async {
    await initialize();
  }

  /// Non-streaming version that returns a Future<String>
  Future<String> sendMultiModalQuery(CameraImage? image, String text) async {
    if (!_isModelLoaded || _session == null) {
      return "Model not loaded yet. Please wait...";
    }

    try {
      Message message;

      if (image != null) {
        // Convert CameraImage to Uint8List (512x512 format)
        final imageBytes = await _convertImageToPngOptimized(image, 256, 256);

        if (imageBytes != null) {
          // Always include some text context with the image
          final prompt = text.isNotEmpty
              ? text
              : "Please describe what you see in this image. And respond to the user query if any. Keep the response concise and relevant within 3 short sentences without markdown formatting.";

          // Add persistent instruction to the message text
          final instruction =
              "Keep the response concise and relevant without unnecessary details.";
          final fullPrompt = "$prompt $instruction";

          message = Message.withImage(
            text: fullPrompt,
            imageBytes: imageBytes,
            isUser: true,
          );
        } else {
          // Add persistent instruction to the message text
          final instruction =
              "Keep the response concise and relevant without unnecessary details.";
          final fullPrompt = text.isEmpty
              ? "Sorry, I couldn't process the image. $instruction"
              : "$text $instruction";

          message = Message.text(text: fullPrompt, isUser: true);
        }
      } else {
        // Text only message
        // Add persistent instruction to the message text
        final instruction =
            "Keep the response concise and relevant without unnecessary details.";
        final fullPrompt = text.isEmpty
            ? "Hello! $instruction"
            : "$text $instruction";

        message = Message.text(text: fullPrompt, isUser: true);
      }

      await _session!.addQueryChunk(message);
      return await _session!.getResponse();
    } catch (e) {
      debugPrint("Error in sendMultiModalQuery: $e");
      return "Sorry, I encountered an error processing your request: $e";
    }
  }

  Stream<String> sendMultiModalQueryStream(
    CameraImage? image,
    String text,
  ) async* {
    if (!_isModelLoaded || _session == null) {
      yield "Model not loaded yet. Please wait...";
      return;
    }

    try {
      Message message;

      if (image != null) {
        debugPrint("Processing image frame...");
        // Convert CameraImage to Uint8List (512x512 format)
        final imageBytes = await _convertImageToPngOptimized(image, 256, 256);

        if (imageBytes != null) {
          debugPrint(
            "Image conversion successful, size: ${imageBytes.length} bytes",
          );
          // Always include some text context with the image
          final prompt = text.isNotEmpty
              ? text
              : "Please describe what you see in this image. ";

          // Add persistent instruction to the message text
          final instruction =
              "Keep the response concise and relevant without unnecessary details. Do not use markdown formatting such as bold or italics or bullet points.";
          final fullPrompt = "$prompt $instruction";

          message = Message.withImage(
            text: fullPrompt,
            imageBytes: imageBytes,
            isUser: true,
          );
        } else {
          debugPrint("Image conversion failed, falling back to text only");
          // Add persistent instruction to the message text
          final instruction =
              "Keep the response concise and relevant without unnecessary details. Do not use markdown formatting such as bold or italics or bullet points.";
          final fullPrompt = text.isEmpty
              ? "Sorry, I couldn't process the image. $instruction"
              : "$text $instruction";

          message = Message.text(text: fullPrompt, isUser: true);
        }
      } else {
        // Text only message
        // Add persistent instruction to the message text
        final instruction =
            "Keep the response concise and relevant without unnecessary details.";
        final fullPrompt = text.isEmpty
            ? "Hello! $instruction"
            : "$text $instruction";

        message = Message.text(text: fullPrompt, isUser: true);
      }

      debugPrint("Adding message to chat...");
      await _session!.addQueryChunk(message);

      debugPrint("Generating response...");
      await for (final chunk in _session!.getResponseAsync()) {
        yield chunk;
      }
    } catch (e) {
      debugPrint("Error in sendMultiModalQuery: $e");
      yield "Sorry, I encountered an error processing your request: $e";
    }
  }

  /// Stream version that accepts pre-captured image bytes from YOLO view
  /// This is useful when using YOLO frames that already have detection overlays
  Stream<String> sendMultiModalQueryStreamWithBytes(
    Uint8List? imageBytes,
    String text,
  ) async* {
    if (!_isModelLoaded || _session == null) {
      yield "Model not loaded yet. Please wait...";
      return;
    }

    try {
      Message message;

      if (imageBytes != null && imageBytes.isNotEmpty) {
        debugPrint(
          "Processing captured image frame, size: ${imageBytes.length} bytes",
        );

        // Always include some text context with the image
        final prompt = text.isNotEmpty
            ? text
            : "Please describe what you see in this image with the detected objects. ";

        // Add persistent instruction to the message text
        final instruction =
            "You are a visual assistant. Your goal is to provide a natural, human-like description of the scene in the image. The image has been pre-processed with analytical overlays to help you identify objects. Your job is to interpret these hints and describe the real-world scene. Your response MUST NOT mention the overlays themselves (like boxes, labels, or confidence scores). Focus solely on describing the environment and answering the user's question concisely in plain text.";
        final fullPrompt = "$prompt $instruction";

        message = Message.withImage(
          text: fullPrompt,
          imageBytes: imageBytes,
          isUser: true,
        );
      } else {
        debugPrint("No image provided, using text only");
        // Add persistent instruction to the message text
        final instruction =
            "You are a visual assistant. Your goal is to provide a natural, human-like description of the scene in the image. The image has been pre-processed with analytical overlays to help you identify objects. Your job is to interpret these hints and describe the real-world scene. Your response MUST NOT mention the overlays themselves (like boxes, labels, or confidence scores). Focus solely on describing the environment and answering the user's question concisely in plain text.";
        final fullPrompt = text.isEmpty
            ? "Hello! $instruction"
            : "$text $instruction";

        message = Message.text(text: fullPrompt, isUser: true);
      }

      debugPrint("Adding message to session...");
      await _session!.addQueryChunk(message);

      debugPrint("Generating response...");
      await for (final chunk in _session!.getResponseAsync()) {
        yield chunk;
      }
    } catch (e) {
      debugPrint("Error in sendMultiModalQueryStreamWithBytes: $e");
      yield "Sorry, I encountered an error processing your request: $e";
    }
  }

  Future<Uint8List?> _convertImageToPng(CameraImage image) async {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertNV21(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888(image);
      }
    } catch (e) {
      debugPrint("Error converting image: $e");
    }
    return null;
  }

  Future<Uint8List?> _convertImageToPngOptimized(
    CameraImage image,
    int maxWidth,
    int maxHeight,
  ) async {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertNV21Optimized(image, maxWidth, maxHeight);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888Optimized(image, maxWidth, maxHeight);
      }
    } catch (e) {
      debugPrint("Error converting image: $e");
    }
    return null;
  }

  Future<Uint8List?> _convertNV21(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;
    final Uint8List yuv420sp = image.planes[0].bytes;

    final img.Image im = img.Image(width: width, height: height);
    final int frameSize = width * height;

    for (int j = 0, yp = 0; j < height; j++) {
      int uvp = frameSize + (j >> 1) * width;
      int u = 0;
      int v = 0;

      for (int i = 0; i < width; i++, yp++) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;

        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }

        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        r = r.clamp(0, 262143) >> 10;
        g = g.clamp(0, 262143) >> 10;
        b = b.clamp(0, 262143) >> 10;

        im.setPixelRgba(i, j, r, g, b, 255);
      }
    }
    return Uint8List.fromList(img.encodePng(im));
  }

  Future<Uint8List?> _convertBGRA8888(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = image.planes[0].bytes;
    final int bytesPerRow = image.planes[0].bytesPerRow;

    final img.Image im = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      rowStride: bytesPerRow,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );
    return Uint8List.fromList(img.encodePng(im));
  }

  Future<Uint8List?> _convertBGRA8888Optimized(
    CameraImage image,
    int maxWidth,
    int maxHeight,
  ) async {
    final int width = image.width;
    final int height = image.height;
    final Uint8List bytes = image.planes[0].bytes;
    final int bytesPerRow = image.planes[0].bytesPerRow;

    img.Image im = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      rowStride: bytesPerRow,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    );

    // Resize image if it's too large
    if (width > maxWidth || height > maxHeight) {
      final double scale = (maxWidth / width).clamp(0.0, maxHeight / height);
      final int newWidth = (width * scale).round();
      final int newHeight = (height * scale).round();
      im = img.copyResize(im, width: newWidth, height: newHeight);
    }

    return Uint8List.fromList(img.encodePng(im));
  }

  Future<Uint8List?> _convertNV21Optimized(
    CameraImage image,
    int maxWidth,
    int maxHeight,
  ) async {
    final int width = image.width;
    final int height = image.height;
    final Uint8List yuv420sp = image.planes[0].bytes;

    // Calculate scale factor
    final double scale = (maxWidth / width).clamp(0.0, maxHeight / height);
    final int newWidth = (width * scale).round();
    final int newHeight = (height * scale).round();

    // Use original dimensions if scale is close to 1
    final int targetWidth = scale > 0.8 ? width : newWidth;
    final int targetHeight = scale > 0.8 ? height : newHeight;

    final img.Image im = img.Image(width: targetWidth, height: targetHeight);
    final int frameSize = width * height;

    // Subsample if resizing
    final int stepX = scale > 0.8 ? 1 : (width / targetWidth).round();
    final int stepY = scale > 0.8 ? 1 : (height / targetHeight).round();

    for (
      int j = 0, yp = 0, targetY = 0;
      j < height && targetY < targetHeight;
      j += stepY, targetY++
    ) {
      int uvp = frameSize + (j >> 1) * width;
      int u = 0;
      int v = 0;

      for (
        int i = 0, targetX = 0;
        i < width && targetX < targetWidth;
        i += stepX, targetX++, yp += stepX
      ) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;

        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }

        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        r = r.clamp(0, 262143) >> 10;
        g = g.clamp(0, 262143) >> 10;
        b = b.clamp(0, 262143) >> 10;

        im.setPixelRgba(targetX, targetY, r, g, b, 255);
      }
      yp += width * (stepY - 1); // Skip rows if subsampling
    }

    return Uint8List.fromList(img.encodePng(im));
  }

  /// Get model download status
  Future<bool> get isModelDownloaded => _gemma.modelManager.isModelInstalled;

  /// Format bytes to human readable format
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Reset the current session
  Future<void> resetSession() async {
    try {
      if (_session != null) {
        // Close the existing session first
        await _session?.close();

        // Create a new session
        _session = await _inferenceModel!.createSession(
          temperature: 1.0,
          randomSeed: 1,
          topK: 1,
          enableVisionModality: true, // Enable vision support
        );
      }
    } catch (e) {
      debugPrint("Error resetting session: $e");
    }
  }

  /// Force garbage collection and cleanup
  Future<void> cleanup() async {
    try {
      // Reset session to clear memory
      await resetSession();

      // Force garbage collection
      if (kDebugMode) {
        debugPrint("Forcing garbage collection for memory cleanup");
      }
    } catch (e) {
      debugPrint("Error during cleanup: $e");
    }
  }

  @override
  void dispose() {
    // Clean up sessions and model
    _session?.close();
    _inferenceModel?.close();
    _gemma.modelManager.deleteModel();
    super.dispose();
  }
}
