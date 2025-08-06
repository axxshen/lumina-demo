import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/depth_estimation_service.dart';

/// A configurable panel for depth estimation settings
class DepthConfigPanel extends StatefulWidget {
  const DepthConfigPanel({super.key});

  @override
  State<DepthConfigPanel> createState() => _DepthConfigPanelState();
}

class _DepthConfigPanelState extends State<DepthConfigPanel> {
  bool _isExpanded = false;
  late TextEditingController _focalLengthController;
  late TextEditingController _imageWidthController;
  late TextEditingController _imageHeightController;
  late TextEditingController _fovController;

  @override
  void initState() {
    super.initState();
    final depthService = DepthEstimationService.instance;
    _focalLengthController = TextEditingController(
      text: depthService.config.focalLengthX.toStringAsFixed(1),
    );
    _imageWidthController = TextEditingController(
      text: depthService.config.imageWidth.toStringAsFixed(0),
    );
    _imageHeightController = TextEditingController(
      text: depthService.config.imageHeight.toStringAsFixed(0),
    );
    
    // Calculate FOV from focal length for display
    final fov = 2 * (180 / math.pi) * 
        math.atan((depthService.config.imageWidth / 2) / depthService.config.focalLengthX);
    _fovController = TextEditingController(text: fov.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _focalLengthController.dispose();
    _imageWidthController.dispose();
    _imageHeightController.dispose();
    _fovController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<DepthEstimationService>(
      builder: (context, depthService, child) {
        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with toggle
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        color: depthService.isEnabled ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Depth Estimation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Enable/Disable Switch
                      Switch(
                        value: depthService.isEnabled,
                        onChanged: (value) => depthService.setEnabled(value),
                        activeColor: Colors.green,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Quick stats (always visible)
              if (!_isExpanded)
                Container(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickStat('Objects', '${depthService.latestResults.length}'),
                      _buildQuickStat('Reliable', '${depthService.latestResults.where((r) => r.isReliable).length}'),
                      _buildQuickStat('Avg Depth', 
                        depthService.averageDepth > 0 
                          ? '${depthService.averageDepth.toStringAsFixed(1)}m'
                          : '-'),
                    ],
                  ),
                ),

              // Expanded configuration panel
              if (_isExpanded) ...[
                const Divider(color: Colors.white24, height: 1),
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistics row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('Total Est.', '${depthService.totalEstimations}'),
                          _buildStat('Current', '${depthService.latestResults.length}'),
                          _buildStat('Reliable', '${depthService.latestResults.where((r) => r.isReliable).length}'),
                          _buildStat('Avg Depth', 
                            depthService.averageDepth > 0 
                              ? '${depthService.averageDepth.toStringAsFixed(1)}m'
                              : '-'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Calculation method dropdown
                      Row(
                        children: [
                          const Text(
                            'Method: ',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<DepthCalculationMethod>(
                              value: depthService.config.method,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Colors.white24),
                                ),
                                filled: true,
                                fillColor: Colors.black26,
                              ),
                              dropdownColor: Colors.black87,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              items: DepthCalculationMethod.values.map((method) {
                                return DropdownMenuItem(
                                  value: method,
                                  child: Text(_getMethodDisplayName(method)),
                                );
                              }).toList(),
                              onChanged: (method) {
                                if (method != null) {
                                  _updateConfig(method: method);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Camera configuration
                      Row(
                        children: [
                          Expanded(
                            child: _buildConfigField(
                              'FOV (°)', 
                              _fovController,
                              onChanged: _updateFromFOV,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildConfigField(
                              'Focal Length', 
                              _focalLengthController,
                              onChanged: _updateFromFocalLength,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildConfigField(
                              'Width', 
                              _imageWidthController,
                              onChanged: _updateFromImageSize,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildConfigField(
                              'Height', 
                              _imageHeightController,
                              onChanged: _updateFromImageSize,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            'Reset to Default',
                            Icons.refresh,
                            () => _resetToDefault(),
                          ),
                          _buildActionButton(
                            'Clear Stats',
                            Icons.clear_all,
                            () => depthService.clearStatistics(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigField(String label, TextEditingController controller, {VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            filled: true,
            fillColor: Colors.black26,
          ),
          keyboardType: TextInputType.number,
          onEditingComplete: onChanged,
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  String _getMethodDisplayName(DepthCalculationMethod method) {
    switch (method) {
      case DepthCalculationMethod.width:
        return 'Width';
      case DepthCalculationMethod.height:
        return 'Height';
      case DepthCalculationMethod.averageDimension:
        return 'Average';
      case DepthCalculationMethod.maxDimension:
        return 'Max Dim';
      case DepthCalculationMethod.minDimension:
        return 'Min Dim';
    }
  }

  void _updateConfig({
    double? focalLengthX,
    double? focalLengthY,
    double? imageWidth,
    double? imageHeight,
    DepthCalculationMethod? method,
  }) {
    final currentConfig = DepthEstimationService.instance.config;
    final newConfig = DepthEstimationConfig(
      focalLengthX: focalLengthX ?? currentConfig.focalLengthX,
      focalLengthY: focalLengthY ?? currentConfig.focalLengthY,
      imageWidth: imageWidth ?? currentConfig.imageWidth,
      imageHeight: imageHeight ?? currentConfig.imageHeight,
      objectSizeDatabase: currentConfig.objectSizeDatabase,
      method: method ?? currentConfig.method,
      maxDepth: currentConfig.maxDepth,
      minDepth: currentConfig.minDepth,
    );
    DepthEstimationService.instance.updateConfig(newConfig);
  }

  void _updateFromFOV() {
    final fov = double.tryParse(_fovController.text);
    final width = double.tryParse(_imageWidthController.text);
    
    if (fov != null && width != null && fov > 0 && fov < 180) {
      final fovRadians = fov * math.pi / 180.0;
      final focalLength = (width / 2) / math.tan(fovRadians / 2);
      
      _focalLengthController.text = focalLength.toStringAsFixed(1);
      _updateConfig(
        focalLengthX: focalLength,
        focalLengthY: focalLength,
        imageWidth: width,
      );
    }
  }

  void _updateFromFocalLength() {
    final focalLength = double.tryParse(_focalLengthController.text);
    if (focalLength != null && focalLength > 0) {
      _updateConfig(
        focalLengthX: focalLength,
        focalLengthY: focalLength,
      );
    }
  }

  void _updateFromImageSize() {
    final width = double.tryParse(_imageWidthController.text);
    final height = double.tryParse(_imageHeightController.text);
    
    if (width != null && height != null && width > 0 && height > 0) {
      _updateConfig(
        imageWidth: width,
        imageHeight: height,
      );
    }
  }

  void _resetToDefault() {
    final defaultConfig = DepthEstimationConfig.mobile();
    DepthEstimationService.instance.updateConfig(defaultConfig);
    
    // Update text controllers
    _focalLengthController.text = defaultConfig.focalLengthX.toStringAsFixed(1);
    _imageWidthController.text = defaultConfig.imageWidth.toStringAsFixed(0);
    _imageHeightController.text = defaultConfig.imageHeight.toStringAsFixed(0);
    
    final fov = 2 * (180 / math.pi) * 
        math.atan((defaultConfig.imageWidth / 2) / defaultConfig.focalLengthX);
    _fovController.text = fov.toStringAsFixed(1);
  }
}

