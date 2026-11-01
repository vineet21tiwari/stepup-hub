import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/theme_state.dart';

const _options = [
  ('light', Icons.light_mode, 'Light'),
  ('dark', Icons.dark_mode, 'Dark'),
  ('auto', Icons.brightness_auto, 'Auto'),
];

/// Light / Dark / Auto segmented toggle — mirrors the web's ThemeToggle.jsx.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeState>().mode;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((o) {
          final selected = mode == o.$1;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.read<ThemeState>().setMode(o.$1),
            child: Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).cardTheme.color : null,
                shape: BoxShape.circle,
                boxShadow: selected ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
              ),
              child: Icon(o.$2, size: 16, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
            ),
          );
        }).toList(),
      ),
    );
  }
}
