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
        ResolutionPreset.medium, // Reduced from veryHigh for memory efficiency
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
