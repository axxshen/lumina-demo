# Lumina - AI Assistant for the Visually Impaired

**"The world sees you."**

Lumina is an innovative Flutter mobile application designed to empower visually impaired individuals through advanced computer vision and AI technologies. The app provides real-time assistance for navigation, object recognition, and environmental understanding.

## Demo

Check out our [demo video](media/demo.mov) to see Lumina in action.

## Features

- **Visual Question Answering (VQA)**: Ask questions about your surroundings and get detailed descriptions powered by AI
- **Real-time Object Detection**: Identify and locate objects in your environment using YOLO deep learning models
- **Depth Estimation**: Calculate distances to objects and surfaces for better spatial awareness
- **Obstacle Avoidance**: Receive intelligent hints and guidance to navigate safely around obstacles
- **Speech Integration**: Hands-free interaction with speech-to-text input and text-to-speech feedback
- **Smart Camera Interface**: Optimized camera controls for accessibility and ease of use

## Prerequisites

### Apple Developer Program Membership

**⚠️ Important**: To run this app on iOS devices, you must have an active **Apple Developer Program** membership ($99/year).

### System Requirements

- **Flutter SDK**: 3.8.1 or compatible
- **Dart SDK**: Compatible with Flutter version
- **iOS Development**:
  - Xcode 14.0 or later
  - iOS 12.0 or later (target device)
  - Valid Apple Developer account
  - Code signing certificate and provisioning profile
- **Android Development** (optional):
  - Android Studio or VS Code with Flutter extension
  - Android SDK (API level 21 or higher)

### Required Device Permissions

The app requires the following permissions to function properly:

- **Camera Access**: For real-time image capture and processing
- **Microphone Access**: For speech-to-text functionality
- **Storage Access**: For caching AI models and temporary data

## Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/axxshen/lumina-demo
cd lumina-demo
```

### 2. Navigate to App Directory

```bash
cd app
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. iOS Setup (Required for iOS deployment)

1. **Open iOS project in Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Configure Code Signing**:
   - Select your development team in Xcode
   - Ensure you have a valid provisioning profile
   - Update the bundle identifier to match your Apple Developer account

3. **Update Entitlements**:
   The app requires specific entitlements in `ios/Runner/Runner.entitlements`:
   ```xml
   <key>com.apple.developer.on-demand-install-capable</key>
   <true/>
   ```

### 5. Run the Application

#### For iOS (Requires Apple Developer Program):
```bash
flutter run -d ios
```

#### For Android:
```bash
flutter run -d android
```

#### For Development/Testing:
```bash
flutter run
```

## Technical Architecture

### Core Technologies

- **Flutter Framework**: Cross-platform mobile development
- **YOLO (Ultralytics)**: Real-time object detection and recognition
- **Flutter Gemma**: On-device AI language model for VQA
- **Computer Vision**: Advanced image processing and depth estimation
- **Speech Technologies**: Integration of STT and TTS for accessibility

### Key Dependencies

- `ultralytics_yolo`: Object detection and computer vision
- `flutter_gemma`: On-device AI language model
- `camera`: Camera access and control
- `speech_to_text`: Voice input processing
- `flutter_tts`: Text-to-speech output
- `provider`: State management
- `permission_handler`: Device permission management

### AI Models

The app utilizes pre-trained deep learning models for:
- Object detection and classification
- Depth estimation algorithms
- Natural language processing for VQA
- Spatial reasoning for obstacle avoidance

## Project Structure

```
app/
├── lib/
│   ├── main.dart              # Application entry point
│   ├── features/              # Feature-specific modules
│   ├── models/                # Data models and AI model interfaces
│   ├── pages/                 # UI screens and pages
│   ├── services/              # Core services (camera, AI, speech)
│   ├── utils/                 # Utility functions and helpers
│   └── widgets/               # Reusable UI components
├── assets/                    # Audio files and app icons
├── ios/                       # iOS-specific configuration
├── android/                   # Android-specific configuration
└── pubspec.yaml              # Project dependencies
```

## Technical Documentation

For detailed implementation guides, including Gemma 3B integration, common challenges, and solutions, see:

📋 **[TECHNICAL_DOCS.md](TECHNICAL_DOCS.md)** - Complete guide for building Lumina from scratch

## Development Guidelines

### Building for Production

1. **iOS**:
   ```bash
   flutter build ios --release
   ```

2. **Android**:
   ```bash
   flutter build apk --release
   ```

### Code Signing (iOS)

Ensure your `ios/Runner.xcodeproj` is properly configured with:
- Valid development team
- Correct bundle identifier
- Appropriate provisioning profile
- Required device capabilities and permissions

## Troubleshooting

### Common Issues

1. **iOS Code Signing Errors**: Verify Apple Developer Program membership and provisioning profiles
2. **Permission Denied**: Ensure all required permissions are granted in device settings
3. **Model Loading Issues**: Check internet connection for initial model downloads
4. **Camera Access**: Verify camera permissions and hardware availability

### Support

For technical support and feature requests, please refer to the project documentation or contact the development team.

---

*Lumina - Empowering independence through AI-powered vision assistance.*