import 'package:flutter/material.dart';

class RouteInfoPanel extends StatelessWidget {
  const RouteInfoPanel({
    super.key,
    required this.distanceText,
    required this.durationText,
    required this.currentMode,
    required this.onModeToggle,
  });

  final String distanceText;
  final String durationText;
  final String currentMode; // 'driving' or 'walking'
  final VoidCallback onModeToggle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Route info',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: onModeToggle,
                    icon: Icon(
                      currentMode == 'driving' ? Icons.directions_car : Icons.directions_walk,
                      color: const Color(0xFF4A90E2),
                      size: 28,
                    ),
                    tooltip: currentMode == 'driving' ? 'Switch to walking' : 'Switch to driving',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Distance: $distanceText'),
              const SizedBox(height: 4),
              Text('Estimated time: $durationText'),
            ],
          ),
        ),
      ),
    );
  }
}