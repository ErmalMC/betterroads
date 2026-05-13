import 'package:flutter/material.dart';

class SearchPanel extends StatelessWidget {
  const SearchPanel({
    super.key,
    required this.isOpen,
    required this.topInset,
    required this.panelHeight,
    required this.startController,
    required this.endController,
    required this.onClear,
    required this.onClose,
    required this.onStartSubmitted,
    required this.onEndSubmitted,
    required this.onSwap,
    required this.canSwap,
  });

  final bool isOpen;
  final double topInset;
  final double panelHeight;
  final TextEditingController startController;
  final TextEditingController endController;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final ValueChanged<String> onStartSubmitted;
  final ValueChanged<String> onEndSubmitted;
  final VoidCallback onSwap;
  final bool canSwap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      top: isOpen ? topInset : topInset - panelHeight - 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: panelHeight),
        child: Material(
          elevation: 4,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            bottom: false,
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Search locations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: onClear,
                              child: const Text('Clear'),
                            ),
                            IconButton(
                              tooltip: 'Close search',
                              onPressed: onClose,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: startController,
                      decoration: const InputDecoration(
                        labelText: 'Start location (lat, lng)',
                        prefixIcon: Icon(Icons.trip_origin),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: onStartSubmitted,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: canSwap ? onSwap : null,
                        icon: const Icon(Icons.swap_vert),
                        label: const Text('Swap'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: endController,
                      decoration: const InputDecoration(
                        labelText: 'Destination (lat, lng)',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: onEndSubmitted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

