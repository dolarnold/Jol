import 'package:flutter/material.dart';

import '../theme/jol_theme.dart';

class JolTabBar extends StatelessWidget {
  const JolTabBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    (label: 'Discover', icon: Icons.home_outlined),
    (label: 'Search', icon: Icons.search),
    (label: 'Host', icon: Icons.add),
    (label: 'Tickets', icon: Icons.confirmation_number_outlined),
    (label: 'Me', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: tokens.tabBar,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: tokens.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var index = 0; index < _destinations.length; index++)
                _TabItem(
                  label: _destinations[index].label,
                  icon: _destinations[index].icon,
                  selected: index == currentIndex,
                  animationDuration: animationDuration,
                  onTap: () => onDestinationSelected(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.animationDuration,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Duration animationDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);

    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: AnimatedContainer(
              duration: animationDuration,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selected ? tokens.surface2 : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 23,
                color: selected ? tokens.text : tokens.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
