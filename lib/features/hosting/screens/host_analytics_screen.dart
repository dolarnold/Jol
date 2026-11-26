import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../../../data/booking/booking_repository.dart';
import '../../../ui/theme/jol_theme.dart';
import '../../../ui/widgets/jol_card.dart';
import '../../discover/models/jol_event.dart';
import '../../discover/widgets/attendee_components.dart';

typedef _AnalyticsQuery = ({String? eventId, String period});

final _analyticsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, _AnalyticsQuery>(
  (ref, query) async {
    final dio = ref.watch(apiClientProvider);
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/host/analytics',
        queryParameters: {'period': query.period, 'event': ?query.eventId},
      );
      final data = response.data?['data'];
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  },
);

/// Views, bookings, money and check-ins for one event or all of them.
class HostAnalyticsScreen extends ConsumerStatefulWidget {
  const HostAnalyticsScreen({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<HostAnalyticsScreen> createState() => _HostAnalyticsScreenState();
}

class _HostAnalyticsScreenState extends ConsumerState<HostAnalyticsScreen> {
  String? _eventId;
  var _period = '30';

  @override
  void initState() {
    super.initState();
    _eventId = widget.eventId;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final hosted = ref.watch(myEventsProvider).value ?? const <HostedEvent>[];
    final ownEvents = hosted.where((item) => item.role == 'host').toList(growable: false);
    final report = ref.watch(_analyticsProvider((eventId: _eventId, period: _period)));
    return Scaffold(
      appBar: AppBar(title: const Text('analytics')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_analyticsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _eventId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Event'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All my events')),
                for (final item in ownEvents)
                  DropdownMenuItem<String?>(
                    value: item.event.id,
                    child: Text(item.event.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _eventId = value),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '30', label: Text('30 days')),
                ButtonSegment(value: '90', label: Text('90 days')),
                ButtonSegment(value: 'all', label: Text('All time')),
              ],
              selected: {_period},
              onSelectionChanged: (value) => setState(() => _period = value.first),
            ),
            const SizedBox(height: 16),
            ...report.when(
              loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
              error: (error, _) => [Text('$error', style: TextStyle(color: tokens.muted))],
              data: (data) => _body(context, data),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, Map<String, dynamic> data) {
    final tokens = JolTokens.of(context);
    final totals = data['totals'] is Map ? Map<String, dynamic>.from(data['totals'] as Map) : <String, dynamic>{};
    int whole(String key) => (totals[key] as num?)?.round() ?? 0;
    String rand(String key) => formatZar((totals[key] as num?)?.round() ?? 0);
    final conversion = totals['conversion'] as num?;
    final days = (data['days'] is List ? data['days'] as List : const [])
        .whereType<Map>()
        .map((day) => (views: (day['views'] as num?)?.toInt() ?? 0, sales: (day['sales'] as num?)?.toDouble() ?? 0))
        .toList(growable: false);
    final sources = (data['sources'] is List ? data['sources'] as List : const []).whereType<Map>().toList();
    final tiles = <(String, String)>[
      ('Views', '${whole('views')}'),
      ('Booked', '${whole('booked')}'),
      ('Conversion', conversion == null ? '–' : '$conversion%'),
      ('Tickets sold', '${whole('tickets_sold')}'),
      ('RSVPs', '${whole('rsvps')}'),
      ('Checked in', '${whole('checked_in')}'),
      ('Sales', rand('gross')),
      ('Fees', rand('fees')),
      ('You get', rand('net')),
    ];
    return [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          for (final (label, value) in tiles)
            JolCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleLarge)),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(color: tokens.muted, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      AttendeeSectionTitle('views per day'),
      JolCard(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: SizedBox(height: 120, child: _Bars(values: days.map((day) => day.views.toDouble()).toList(), color: tokens.accent)),
      ),
      const SizedBox(height: 14),
      AttendeeSectionTitle('sales per day'),
      JolCard(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: SizedBox(height: 120, child: _Bars(values: days.map((day) => day.sales).toList(), color: const Color(0xFF2E9E6A))),
      ),
      if (sources.isNotEmpty) ...[
        const SizedBox(height: 14),
        AttendeeSectionTitle('where views came from'),
        JolCard(
          child: Column(
            children: [
              for (final source in sources)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${source['label']}')),
                      Text('${source['views']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

/// A simple bar chart: one bar per day, tallest = full height.
class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final top = values.fold<double>(0, (max, value) => value > max ? value : max);
    if (values.isEmpty || top <= 0) {
      return Center(child: Text('Nothing yet', style: TextStyle(color: tokens.muted)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: FractionallySizedBox(
                heightFactor: value <= 0 ? .02 : (value / top < .04 ? .04 : value / top),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: value <= 0 ? tokens.line : color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
