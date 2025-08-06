import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  bool _manualStop = false; // Track if stop was manual

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
      _recognizedText = ''; // Clear previous text
      _speech.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          notifyListeners();
        },
        onSoundLevelChange: (level) {
          // Optional: Handle sound level changes if needed
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
