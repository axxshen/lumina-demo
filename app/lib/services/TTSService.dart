import 'package:flutter/foundation.dart';
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
  final int _minChunkLength = 15; // Minimum characters to speak
  final int _maxBufferLength = 50; // Maximum buffer before forced speech
  final bool _canStartEarly = true; // Allow early speech start
  
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
        // Use a simpler configuration that's more likely to work
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

      flutterTts.setCompletionHandler(() {
        debugPrint("[TTS] Speech completed");
        _isSpeaking = false;
        // Use a small delay to ensure state is reset properly
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isSpeaking && _speakQueue.isNotEmpty) {
            debugPrint("[TTS] Continuing queue after completion");
            _processQueue();
          }
        });
      });

      flutterTts.setErrorHandler((msg) {
        debugPrint("[TTS] Error: $msg");
        _isSpeaking = false;
        // Use a small delay to ensure state is reset properly
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isSpeaking && _speakQueue.isNotEmpty) {
            debugPrint("[TTS] Continuing queue after error");
            _processQueue();
          }
        });
      });

      flutterTts.setStartHandler(() {
        debugPrint("[TTS] Speech started");
      });

      debugPrint("[TTS] TTS initialized successfully");
      
      // Ensure no auto-playing sounds during initialization
      await flutterTts.stop();
    } catch (e) {
      debugPrint("[TTS] Initialization error: $e");
    }
  }

  // Original speak method for complete text
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Split text into sentences for smoother playback
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    _speakQueue.addAll(sentences.where((s) => s.trim().isNotEmpty));

    if (!_isSpeaking) {
      await _processQueue();
    }
  }

  // Method to reset TTS state before new session
  Future<void> resetForNewSession() async {
    debugPrint("[TTS] Resetting for new session");
    _bufferTimer?.cancel();
    _speakQueue.clear();
    _streamBuffer = '';
    _isStreaming = false;
    _isSpeaking = false;
    await flutterTts.stop();
  }

  // New method for streaming TTS
  void startStreaming() {
    debugPrint("[TTS] Starting streaming TTS");
    _isStreaming = true;
    _streamBuffer = '';
    _bufferTimer?.cancel();
  }

  void addStreamChunk(String chunk) {
    if (!_isStreaming) {
      debugPrint("[TTS] Chunk received but not streaming: $chunk");
      return;
    }

    debugPrint("[TTS] Adding chunk: '$chunk'");
    _streamBuffer += chunk;

    // Cancel previous timer
    _bufferTimer?.cancel();

    // More aggressive real-time processing
    if (_streamBuffer.length >= _minChunkLength) {
      // Process immediately if we have enough content
      _processStreamBuffer();
    } else {
      // Much shorter delay for smaller chunks
      _bufferTimer = Timer(const Duration(milliseconds: 50), () {
        _processStreamBuffer();
      });
    }
  }

  void _processStreamBuffer() {
    if (_streamBuffer.isEmpty) return;

    debugPrint("[TTS] Processing buffer: '$_streamBuffer'");

    // First, check for complete sentences
    final sentences = _streamBuffer.split(RegExp(r'(?<=[.!?])\s+'));

    if (sentences.length > 1) {
      debugPrint("[TTS] Found ${sentences.length} sentences");
      // We have complete sentences, speak them
      for (int i = 0; i < sentences.length - 1; i++) {
        final sentence = sentences[i].trim();
        if (sentence.isNotEmpty) {
          debugPrint("[TTS] Adding sentence to queue: '$sentence'");
          _speakQueue.add(sentence);
        }
      }

      // Keep the last incomplete sentence in buffer
      _streamBuffer = sentences.last;

      // Start speaking if not already speaking
      if (!_isSpeaking) {
        debugPrint("[TTS] Starting to process queue");
        _processQueue();
      }
    } else {
      // No complete sentences, but process chunks more aggressively
      if (_streamBuffer.length >= _maxBufferLength) {
        debugPrint(
          "[TTS] Buffer at max length (${_streamBuffer.length}), forcing speech",
        );
        // Find a good breaking point (space, comma, etc.)
        final breakPoint = _streamBuffer.lastIndexOf(RegExp(r'[,;:\s]'));
        if (breakPoint > _minChunkLength) {
          final chunk = _streamBuffer.substring(0, breakPoint + 1).trim();
          if (chunk.isNotEmpty) {
            debugPrint("[TTS] Adding forced chunk to queue: '$chunk'");
            _speakQueue.add(chunk);
            _streamBuffer = _streamBuffer.substring(breakPoint + 1);

            if (!_isSpeaking) {
              _processQueue();
            }
          }
        }
      } else if (_streamBuffer.length >= _minChunkLength && _canStartEarly) {
        // Look for natural break points even in smaller chunks
        final breakPoints = ['. ', '! ', '? ', ', ', '; ', ': '];
        int bestBreakPoint = -1;

        for (String breakPoint in breakPoints) {
          final index = _streamBuffer.indexOf(breakPoint);
          if (index > _minChunkLength &&
              (bestBreakPoint == -1 || index < bestBreakPoint)) {
            bestBreakPoint = index + breakPoint.length;
          }
        }

        if (bestBreakPoint > 0) {
          final chunk = _streamBuffer.substring(0, bestBreakPoint).trim();
          if (chunk.isNotEmpty) {
            debugPrint("[TTS] Adding early chunk to queue: '$chunk'");
            _speakQueue.add(chunk);
            _streamBuffer = _streamBuffer.substring(bestBreakPoint);

            if (!_isSpeaking) {
              _processQueue();
            }
          }
        }
      }
    }
  }

  void finishStreaming() {
    _isStreaming = false;
    _bufferTimer?.cancel();

    // Speak any remaining content in buffer
    if (_streamBuffer.trim().isNotEmpty) {
      _speakQueue.add(_streamBuffer.trim());
      _streamBuffer = '';

      if (!_isSpeaking) {
        _processQueue();
      }
    }
  }

  Future<void> _processQueue() async {
    if (_speakQueue.isEmpty || _isSpeaking) {
      debugPrint(
        "[TTS] Queue processing skipped - isEmpty: ${_speakQueue.isEmpty}, isSpeaking: $_isSpeaking",
      );
      return;
    }

    _isSpeaking = true;
    final sentence = _speakQueue.removeAt(0);

    debugPrint("[TTS] Speaking: '$sentence'");

    try {
      // Use await to ensure proper sequencing
      await flutterTts.speak(sentence);
    } catch (e) {
      debugPrint("TTS Error: $e");
      _isSpeaking = false;
      // Continue processing queue even if one item fails
      if (_speakQueue.isNotEmpty) {
        _processQueue();
      }
    }
  }

  Future<void> stop() async {
    _speakQueue.clear();
    _isSpeaking = false;
    await flutterTts.stop();
    // Clear and reset streaming
    _streamBuffer = '';
  }
  
  // Play a hint sound when recording starts
  Future<void> playHintSound() async {
    try {
      // Configure for hint sound - quick and subtle
      await flutterTts.setSpeechRate(2.0); // Faster
      await flutterTts.setPitch(1.5); // Higher pitch
      await flutterTts.setVolume(0.3); // Lower volume
      
      // Play a very short sound
      await flutterTts.speak("•"); // Single bullet point character makes a short sound
      
      // Wait briefly for the sound to complete
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Restore original settings
      await flutterTts.setSpeechRate(_originalSpeechRate);
      await flutterTts.setPitch(_originalPitch);
      await flutterTts.setVolume(_originalVolume);
      
      debugPrint("[TTS] Hint sound played");
    } catch (e) {
      debugPrint("[TTS] Error playing hint sound: $e");
      // If TTS fails, we can still continue - the hint sound is optional
      // Restore settings anyway
      try {
        await flutterTts.setSpeechRate(_originalSpeechRate);
        await flutterTts.setPitch(_originalPitch);
        await flutterTts.setVolume(_originalVolume);
      } catch (restoreError) {
        debugPrint("[TTS] Error restoring settings: $restoreError");
      }
    }
  }

  @override
  void dispose() {
    _bufferTimer?.cancel();
    _isStreaming = false;
    stop();
    flutterTts.stop();
    super.dispose();
  }
}
