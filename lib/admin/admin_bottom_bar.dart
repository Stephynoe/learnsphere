import 'dart:ui';

import 'package:flutter/material.dart';

enum AdminDestination {
  dashboard('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
  courses('Courses', Icons.menu_book_outlined, Icons.menu_book),
  learners('Learners', Icons.group_outlined, Icons.group),
  enrollments('Enrollments', Icons.how_to_reg_outlined, Icons.how_to_reg),
  more('More', Icons.more_horiz, Icons.more_horiz);

  const AdminDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon, selectedIcon;
}

/// Shared bottom navigation for the administrator workspace.
class AdminBottomBar extends StatelessWidget {
  const AdminBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AdminDestination selected;
  final ValueChanged<AdminDestination> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 10,
          offset: Offset(0, -2),
        ),
      ],
    ),
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: const Color(0xE6F9F9FF),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    for (final destination in AdminDestination.values)
                      Expanded(child: _item(destination)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _item(AdminDestination destination) {
    final active = destination == selected;
    final color = active ? const Color(0xFFF97316) : const Color(0xFF584237);
    return Semantics(
      selected: active,
      button: true,
      child: InkWell(
        key: ValueKey('admin_nav_${destination.name}'),
        onTap: () => onSelected(destination),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
