# Lumina: AI Assistive Navigation for the Visually Impaired [iOS/Android]

## Executive Summary

Lumina demonstrates Gemma 3n's great potential for critical accessibility applications by delivering real-time scene understanding entirely on-device. Our Flutter application combines computer vision, depth estimation, and multimodal AI to create an offline navigation assistant for visually impaired users. The system processes camera feeds at `30 FPS`, provides voice responses as fast as `~1` second on iOS device with 8GB RAM, and operates without network connectivity at all.

## Technical Architecture

### Core Innovation: Tailored Offline Multimodal Intelligence for the Visually Impaired

Lumina's architecture centers on Gemma 3n as the multimodal reasoning engine, orchestrating three interactive data streams:

1. **Visual Processing**: YOLOv11-nano object detection (30 FPS) + depth estimation
2. **Audio Input**: Real-time speech-to-text via platform-native speech recognition services
3. **Voice Output**: Streaming text-to-speech with lowest latency

### Gemma 3n Integration Strategy`

**Model Configuration**: We deploy the 2-billion parameter Gemma 3n variant with 4-bit quantization, reducing memory footprint while maintaining its strong multimodal capabilities. The model runs via flutter_gemma plugin with GPU acceleration. Thanks to the great contributors from the community, they provided further optimizations for mobile deployment with function callings and more.

**Prompt Engineering**: Our template fuses three modalities:

- Image tokens (256×256 preprocessed frames) for general description
- Object detection & depth estimation markers for effective attention
- Live speech transcripts for effective responses to user queries

### Computer Vision Pipeline

**Object Detection**: YOLOv11-nano processes at 15 ~ 30 FPS, detecting `80+` COCO classes with ~25MB model footprint. This maintains real-time performance potentially on older iOS devices.

**Depth Estimation**: Instead of running memory-intensive depth estimation models, we implemented mathematical solution of depth estimation to achieve similar performance:

- Pinhole camera model: Z = (f × W) / w
- Real-world object dimensions database (manually curated for `70+` COCO classes for our demo)
- Confidence scoring for depth estimation based on object size reliability

**Obstacle Assessment**: A custom fusion service converts detection bounding boxes and depth estimates into risk scores (0-1 scale) for navigation guidance. The results can provide accurate vibration alerts within `1-meter` effective signal range to help prevent collisions for the users.

## Engineering Challenges and Solutions

### Challenge 1: iOS Memory Management

**Problem**: Running YOLO + Gemma 3n + camera simultaneously triggered OOM (Out Of Memory) crashes.

**Solution**: Implemented multi-layered optimization strategy including `FP16` precision for GPU acceleration, image token trade-off (from 512×512 to 256×256), and adaptive memory management. 

### Challenge 2: Real-Time Voice Interaction

**Problem**: Traditional request-response patterns created unacceptable latency for visually impaired users requiring immediate spatial awareness.

**Solution**: Developed streaming architecture where TTS begins speaking partial Gemma responses while token generation continues. Together with our effective GPU acceleration, this reduces perceived time to first token from `~7` seconds to `~1` second in the optimal device situation.

### Challenge 3: Multimodal Prompt Optimization

**Problem**: Naive multimodal prompting produced verbose, irrelevant responses unsuitable for navigation assistance & Need for correct understanding of the YOLO detection results.

**Solution**: Iterative prompt engineering focused on concise, navigation-relevant information, reducing response time by 20% while improving relevance significantly.

## Performance Validation

**Hardware**: iPhone 16

- Object Detection: 15 ~ 30 FPS @ 1280×720
- Depth Estimation: Real-time 
- Gemma Response: ~1s to the first token
- Memory Usage: ~2.5GB peak (within iOS limits)

**Scalability**: This on-device optimization enhances both efficiency and performance across hardware generations and on both Android and iOS devices, which opens up great accessibility potential for the visually impaired community.

## Why Gemma 3n Enables This Application

**On-Device Capability**: Gemma 3n's mobile-optimized architecture makes sophisticated multimodal AI accessible without cloud dependencies—critical for accessibility applications where reliability matters more than perfect accuracy.

**Multimodal Understanding**: The model's native image+text processing eliminates complex pipeline orchestration, reducing latency and simplifying error handling.

**Resource Efficiency**: 4-bit quantization support allows deployment on consumer hardware while maintaining sufficient reasoning capability for real-world navigation tasks.

## Impact and Future Directions

Lumina demonstrates that modern on-device AI can address critical accessibility needs without compromising privacy or requiring constant connectivity. Millions of potential users who are visually impaired represent one of AI's most underserved populations.

**Lessons Learned**: This project proves that thoughtful engineering can overcome mobile AI constraints through hybrid approaches—combining neural networks where they excel (multimodal reasoning) with classical algorithms where they're more efficient in some ways. Given the bright future of on-device AI, the turning point will come when we can run the smartest model on the affordable devices so that people are actually benefited. This is also where the Lumina project aims to contribute now and in the future.

**Future Technical Roadmap**:

- Multilingual support leveraging Gemma's language capabilities
- Optimized depth estimation with more robust algorithms or models
- Optimize for Android & iOS devices to ensure cross-platform accessibility
- Proactive voice guidance based on real-time scene analysis (requiring more memory optimization)

## Conclusion

Lumina validates Gemma 3n as a foundation for privacy-preserving, accessibility-focused AI mobile applications. By demonstrating that sophisticated multimodal understanding can run entirely on consumer devices (both on Android and iOS), this work opens new possibilities for AI systems that serve users without compromising their data or requiring expensive infrastructure or hardware.

The complete product demo showcases Gemma 3n's great potential beyond traditional chatbot applications, proving its viability for latency-sensitive, real-world use cases where failure isn't just inconvenient—it's dangerous.

Source code available at: https://github.com/axxshen/lumina-demo
Video Demo on Youtube: https://www.youtube.com/watch?v=G3-jX3C1phU

*Credits: Ao Shen, Pushparaja Murugan*

