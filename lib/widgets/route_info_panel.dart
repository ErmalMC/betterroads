import 'package:flutter/material.dart';

class RouteInfoPanel extends StatelessWidget {
  const RouteInfoPanel({
    super.key,
    required this.distanceText,
    required this.durationText,
  });

  final String distanceText;
  final String durationText;

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
              Text(
                'Route info',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Distance: $distanceText'),
              Text('Estimated time: $durationText'),
            ],
          ),
        ),
      ),
    );
  }
}

