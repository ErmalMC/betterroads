import 'package:flutter/material.dart';

class RouteInfoPanel extends StatelessWidget {
  const RouteInfoPanel({
    super.key,
    required this.distanceText,
    required this.durationText,
    required this.currentMode,
    required this.onModeToggle,
    this.isLoading = false,
  });

  final String distanceText;
  final String durationText;
  final String currentMode; // 'driving' or 'walking'
  final VoidCallback onModeToggle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Return the panel widget itself. Positioning is handled by the parent
    // (e.g. `Positioned` in the screen) so the panel can be placed at the
    // top or bottom depending on the caller.
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Route info',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    if (isLoading)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF4A90E2),
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: isLoading ? null : onModeToggle,
                      icon: Icon(
                        currentMode == 'driving' ? Icons.directions_car : Icons.directions_walk,
                        color: isLoading ? Colors.grey : const Color(0xFF4A90E2),
                        size: 28,
                      ),
                      tooltip: currentMode == 'driving' ? 'Switch to walking' : 'Switch to driving',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Calculating route...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distance: $distanceText'),
                  const SizedBox(height: 4),
                  Text('Estimated time: $durationText'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}