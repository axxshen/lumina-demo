import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'services/CameraService.dart';
import 'services/SpeechService.dart';
import 'services/TTSService.dart';
import 'services/gemma_service.dart';
import 'services/yolo_service.dart';
import 'services/depth_estimation_service.dart';
import 'services/obstacle_avoidance_service.dart';
import 'features/setup/model_setup_screen.dart';
import 'widgets/detection_overlay.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置全屏模式，隐藏状态栏和导航栏
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [], // 完全隐藏状态栏和导航栏
  );

  runApp(MyApp());
}

// Main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        ChangeNotifierProvider(
          create: (_) => ObstacleAvoidanceService.instance,
        ),
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

// Main camera application widget
class CameraApp extends StatefulWidget {
  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

// State for the CameraApp
class _CameraAppState extends State<CameraApp> with TickerProviderStateMixin {
  //
  bool _isProcessing = false;
  String _currentResponse = '';
  bool _showDetectionInfo = false;
  bool _showClearButton = false;

  // Border color based on obstacle distance
  Color _borderColor = Colors.transparent;

  // Animation controller for blinking effect
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    Provider.of<SpeechService>(context, listen: false).initialize();
    // Initialize YOLO service
    Provider.of<YOLOService>(context, listen: false).initialize();
    // Gemma is already initialized from the setup screen

    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Blinking controller for title
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // Make pulse animation repeat
    _pulseController.repeat(reverse: true);
  }

  Future<void> _handleVoiceButtonTap() async {
    if (_isProcessing) {
      return;
    }
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final ttsService = Provider.of<TTSService>(context, listen: false);

    if (!speechService.isListening) {
      // Ensure TTS is stopped during recording to prevent feedback
      await ttsService.stop();

      // Start recording
      // Play hint sound FIRST to avoid delay
      await ttsService.playHintSound();

      // Then provide haptic feedback and scale animation
      HapticFeedback.lightImpact();
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });

      // Start listening
      speechService.startListening();
    } else {
      // For stop action, do animation first since no sound is needed
      HapticFeedback.lightImpact();
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });

      // Stop recording and process
      speechService.stopListening();

      // Process the recorded speech
      await _processVoiceInput();
    }
  }

  Future<void> _processVoiceInput() async {
    final yoloService = Provider.of<YOLOService>(context, listen: false);
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final gemmaService = Provider.of<GemmaService>(context, listen: false);
    final ttsService = Provider.of<TTSService>(context, listen: false);

    if (gemmaService.isReady && yoloService.isReady) {
      setState(() {
        _isProcessing = true;
        _showClearButton = false; // Hide clear button during processing
      });

      try {
        setState(() => _currentResponse = ''); // Clear previous response
        String buffer = '';

        // Reset TTS state before starting new session
        await ttsService.resetForNewSession();

        // Start streaming TTS
        ttsService.startStreaming();

        // Capture current frame from YOLO view
        final capturedImageBytes = await yoloService.yoloController
            .captureFrame();

        // Process the streaming response
        await for (final chunk
            in gemmaService.sendMultiModalQueryStreamWithBytes(
              capturedImageBytes,
              speechService.recognizedText,
            )) {
          buffer += chunk;

          // Update UI with current response
          setState(() => _currentResponse = buffer);

          // Add chunk to TTS for real-time speaking
          ttsService.addStreamChunk(chunk);
        }

        // Finish streaming TTS
        ttsService.finishStreaming();

        // Show clear button after response generation completes
        setState(() {
          _showClearButton = true;
        });
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    } else {
      if (!gemmaService.isReady) {
        ttsService.speak("Gemma model is not ready yet.");
      } else if (!yoloService.isReady) {
        ttsService.speak("Camera is not ready yet.");
      }
    }
  }

  @override
  void dispose() {
    // Clean up animation controllers
    _pulseController.dispose();
    _scaleController.dispose();
    _blinkController.dispose();
    // Clean up like in flutter_gemma example
    Provider.of<GemmaService>(context, listen: false).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<YOLOService>(
        builder: (context, yoloService, child) {
          // Show loading screen while YOLO model is loading
          if (yoloService.isModelLoading) {
            return Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 32),
                    Text(
                      yoloService.loadingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (yoloService.downloadProgress > 0)
                      Column(
                        children: [
                          SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              value: yoloService.downloadProgress,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(yoloService.downloadProgress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }

          // Show error if model failed to load
          if (!yoloService.isReady) {
            return const Center(
              child: Text(
                'Failed to load YOLO model',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return SizedBox.expand(
            child: Stack(
              children: [
                // Fullscreen YOLO View with detection overlays and depth indicators
                Consumer<DepthEstimationService>(
                  builder: (context, depthService, child) {
                    return Consumer<ObstacleAvoidanceService>(
                      builder: (context, obstacleService, child) {
                        // Only update title color and blink if obstacle avoidance is enabled
                        if (obstacleService.isEnabled) {
                          // Update the title color based on nearest object
                          if (yoloService.detectionResults.isNotEmpty &&
                              depthService.latestResults.isNotEmpty) {
                            final nearestDepthResult = depthService
                                .latestResults
                                .reduce(
                                  (a, b) => a.estimatedDepth < b.estimatedDepth
                                      ? a
                                      : b,
                                );

                            Color newBorderColor = Colors.transparent;
                            bool shouldBlink = false;

                            if (nearestDepthResult.estimatedDepth < 0.5) {
                              // warningThreshold
                              newBorderColor = Colors.red;
                              shouldBlink = true;
                            } else if (nearestDepthResult.estimatedDepth <
                                1.0) {
                              // safetyThreshold
                              newBorderColor = Colors.orange;
                              shouldBlink = true;
                            }

                            if (_borderColor != newBorderColor) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setState(() => _borderColor = newBorderColor);
                                if (shouldBlink &&
                                    !_blinkController.isAnimating) {
                                  _blinkController.repeat(reverse: true);
                                } else if (!shouldBlink &&
                                    _blinkController.isAnimating) {
                                  _blinkController.stop();
                                  _blinkController.reset();
                                }
                              });
                            }
                          } else {
                            // No detections, clear border
                            if (_borderColor != Colors.transparent) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setState(
                                  () => _borderColor = Colors.transparent,
                                );
                                if (_blinkController.isAnimating) {
                                  _blinkController.stop();
                                  _blinkController.reset();
                                }
                              });
                            }
                          }
                        } else {
                          // Obstacle avoidance is disabled - clear border and stop blinking
                          if (_borderColor != Colors.transparent ||
                              _blinkController.isAnimating) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => _borderColor = Colors.transparent);
                              if (_blinkController.isAnimating) {
                                _blinkController.stop();
                                _blinkController.reset();
                              }
                            });
                          }
                        }

                        return DetectionOverlay(
                          detections: yoloService.detectionResults,
                          depthResults: depthService.latestResults,
                          child: YOLOView(
                            modelPath: yoloService.modelPath!,
                            task: yoloService.selectedModel.task,
                            controller: yoloService.yoloController,
                            onResult: yoloService.onDetectionResults,
                            onPerformanceMetrics:
                                yoloService.onPerformanceMetrics,
                            confidenceThreshold:
                                yoloService.confidenceThreshold,
                            iouThreshold: yoloService.iouThreshold,
                          ),
                        );
                      },
                    );
                  },
                ),

                // Floating AppBar replacement at top
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _blinkAnimation,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                // Always have a border to prevent size changes
                                border: Border.all(
                                  color: _blinkController.isAnimating
                                      ? _borderColor.withValues(
                                          alpha: _blinkAnimation.value,
                                        )
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                // Apple Intelligence-style subtle glow
                                boxShadow: _blinkController.isAnimating
                                    ? [
                                        BoxShadow(
                                          color: _borderColor.withValues(
                                            alpha: _blinkAnimation.value * 0.3,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : [],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Lumina',
                                    style: TextStyle(
                                      color: Colors.white, // Always white
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    GemmaService.instance.isReady
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: GemmaService.instance.isReady
                                        ? Colors.green
                                        : Colors.red,
                                    size: 18,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Settings button (top right)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 20,
                  child: Semantics(
                    button: true,
                    label: 'Settings',
                    child: GestureDetector(
                      onTap: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );

                        // Refresh the overlay when settings change
                        if (result != null &&
                            (result['depth_estimation_changed'] == true ||
                                result['obstacle_avoidance_changed'] == true)) {
                          setState(() {
                            // Force rebuild to apply settings
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                // Navigation button with dropdown info (top left)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        button: true,
                        label: _showDetectionInfo
                            ? 'Hide detections'
                            : 'Show detections',
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showDetectionInfo = !_showDetectionInfo;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      if (_showDetectionInfo)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'DETECTIONS: ${yoloService.detectionCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'FPS: ${yoloService.currentFps.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Speech recognition and response text (center of screen)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Consumer<SpeechService>(
                          builder: (context, speechService, child) {
                            if (speechService.recognizedText.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                speechService.recognizedText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                        if (_currentResponse.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(
                              top: 12,
                              left: 20,
                              right: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _currentResponse,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (_showClearButton)
                          Container(
                            margin: const EdgeInsets.only(
                              top: 16,
                              left: 20,
                              right: 20,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentResponse = '';
                                  _showClearButton = false;
                                });
                                // Clear the speech service text as well
                                Provider.of<SpeechService>(
                                  context,
                                  listen: false,
                                ).clearText();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_isProcessing) Center(child: CircularProgressIndicator()),

                // Floating voice button at bottom center
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Consumer<SpeechService>(
                          builder: (context, speechService, child) {
                            final isListening = speechService.isListening;
                            return Semantics(
                              button: true,
                              enabled: true,
                              label: isListening
                                  ? 'Stop recording'
                                  : 'Start recording',
                              hint: isListening
                                  ? 'Tap to stop recording and process your speech'
                                  : 'Tap to start recording your voice',
                              child: GestureDetector(
                                onTap: () async {
                                  await _handleVoiceButtonTap();
                                },
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    _pulseAnimation,
                                    _scaleAnimation,
                                  ]),
                                  builder: (context, child) {
                                    final pulseValue = isListening
                                        ? _pulseAnimation.value
                                        : 1.0;
                                    final scaleValue = _scaleAnimation.value;

                                    return Transform.scale(
                                      scale: pulseValue * scaleValue,
                                      child: Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: isListening
                                              ? Colors.red.withValues(
                                                  alpha: 0.9,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: isListening
                                                  ? Colors.red.withValues(
                                                      alpha: 0.4,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.3,
                                                    ),
                                              blurRadius: isListening ? 20 : 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          isListening ? Icons.stop : Icons.mic,
                                          size: 40,
                                          color: isListening
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Accessibility label
                        const Text(
                          'Speak',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
