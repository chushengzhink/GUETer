import 'package:flutter/material.dart';

/// Immediate, accessible Material navigation. Selection never waits for animation.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavBarItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    if (items.length == 1) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Semantics(
              selected: true,
              child: TextButton.icon(
                onPressed: () => onTap(0),
                icon: Icon(items.single.icon),
                label: Text(items.single.label),
              ),
            ),
          ),
        ),
      );
    }
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index != currentIndex) onTap(index);
      },
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.icon), label: item.label),
      ],
    );
  }
}

class FloatingNavBarItem {
  const FloatingNavBarItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
