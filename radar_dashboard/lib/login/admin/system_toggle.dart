// system_toggle.dart
import 'package:flutter/material.dart';

class SystemToggle extends StatelessWidget {
  final int selectedSystem;
  final Function(int) onSystemChanged;

  const SystemToggle({
    super.key,
    required this.selectedSystem,
    required this.onSystemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'system_toggle',
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SystemToggleButton(
                  title: "Dashboard System",
                  isSelected: selectedSystem == 0,
                  icon: Icons.dashboard,
                  onTap: () => onSystemChanged(0),
                ),
              ),
              Expanded(
                child: _SystemToggleButton(
                  title: "Project Radar App",
                  isSelected: selectedSystem == 1,
                  icon: Icons.radar,
                  onTap: () => onSystemChanged(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemToggleButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _SystemToggleButton({
    required this.title,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C5282) : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF2C5282).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6), 
              size: 24
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}