import 'package:flutter/material.dart';

import '../../../data/mocks/mock_attendee_events.dart';
import '../../../ui/theme/jol_theme.dart';
import '../../../ui/widgets/jol_card.dart';
import '../models/jol_event.dart';
import 'jol_poster.dart';

JolEvent? findAttendeeEvent(String id) {
  for (final event in mockAttendeeEvents) {
    if (event.id == id) return event;
  }
  return null;
}

String eventDateStamp(DateTime date) =>
    "'${(date.year % 100).toString().padLeft(2, '0')} "
    "${date.month.toString().padLeft(2, '0')} "
    "${date.day.toString().padLeft(2, '0')}";

class AttendeeScreenHeader extends StatelessWidget {
  const AttendeeScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: tokens.text,
                    letterSpacing: -1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AttendeeSectionTitle extends StatelessWidget {
  const AttendeeSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'ArchivoExpanded',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AttendeePosterCard extends StatelessWidget {
  const AttendeePosterCard({
    super.key,
    required this.event,
    required this.onTap,
    this.compact = false,
    this.trailing,
    this.distance,
  });

  final JolEvent event;
  final VoidCallback onTap;
  final bool compact;
  final Widget? trailing;

  /// e.g. "2.4 km", shown when Discover is sorted by distance.
  final String? distance;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final height = compact ? 122.0 : 142.0;
    return Semantics(
      button: true,
      label: '${event.title}, ${formatEventDate(event.date)}, ${event.address}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: JolCard(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              JolPoster(
                style: event.posterStyle,
                primary: Color(event.posterPrimary),
                secondary: Color(event.posterSecondary),
                title: event.title,
                area: event.area,
                dateStamp: eventDateStamp(event.date),
                imageUrl: event.coverImageUrl,
                size: Size(height * .77, height),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatEventDate(event.date).toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'ArchivoExpanded',
                          fontWeight: FontWeight.w600,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          event.startTime,
                          event.area,
                          ?distance,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.muted,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.attendanceText,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: event.isSoldOut
                                        ? tokens.muted
                                        : tokens.text,
                                  ),
                            ),
                          ),
                          ?trailing,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendeeIconButton extends StatelessWidget {
  const AttendeeIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(icon, semanticLabel: label),
      color: tokens.text,
    );
  }
}

class AttendeeEmptyState extends StatelessWidget {
  const AttendeeEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined, size: 38, color: tokens.muted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'ArchivoExpanded',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.muted,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class MockCategoryArt extends StatelessWidget {
  const MockCategoryArt({
    super.key,
    required this.category,
    required this.height,
  });

  final String category;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = mockCategoryColors[category] ??
        mockCategoryColors.values.first;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: colors.map(Color.new).toList(),
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -24,
            top: -40,
            child: Icon(
              switch (category) {
                'nightlife' => Icons.nightlife_outlined,
                'fitness' => Icons.directions_run_outlined,
                _ => Icons.people_outline,
              },
              size: 180,
              color: Colors.white.withValues(alpha: .22),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                category,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontFamily: 'ArchivoExpanded',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
