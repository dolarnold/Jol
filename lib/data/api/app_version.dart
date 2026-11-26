import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_button.dart';

/// This build's version, sent to the API on every request as X-App-Version.
class AppBuild {
  static String version = '';
  static String build = '';

  static String get platform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => 'other',
  };

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {
      // Tests / unsupported platforms: just don't send a version.
    }
  }
}

@immutable
class AppUpdate {
  const AppUpdate({required this.required, this.latest, this.message, this.storeUrl});

  /// True: this version may no longer be used (blocking screen).
  final bool required;
  final String? latest;
  final String? message;
  final String? storeUrl;

  factory AppUpdate.fromJson(Map<String, dynamic> json) => AppUpdate(
    required: json['update'] == 'required',
    latest: json['latest_version'] as String?,
    message: json['message'] as String?,
    storeUrl: json['store_url'] as String?,
  );
}

/// null = up to date (or the "new version" note was closed).
class AppUpdateNotifier extends Notifier<AppUpdate?> {
  @override
  AppUpdate? build() => null;

  void show(AppUpdate update) {
    // Never downgrade a blocking update to a dismissible one.
    if (state?.required == true && !update.required) return;
    state = update;
  }

  void dismiss() {
    if (state?.required == true) return;
    state = null;
  }

  /// Asks the server whether this version is still supported.
  Future<void> check(Dio dio) async {
    if (AppBuild.version.isEmpty) return;
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/app/version',
        queryParameters: {'version': AppBuild.version, 'platform': AppBuild.platform},
      );
      final data = response.data?['data'];
      if (data is Map && data['update'] != null) {
        show(AppUpdate.fromJson(Map<String, dynamic>.from(data)));
      }
    } catch (_) {
      // Offline or server asleep: try again next launch.
    }
  }
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdate?>(AppUpdateNotifier.new);

/// Wraps the whole app: a blocking "Update JOL" screen, or a small note
/// at the bottom when a newer (optional) version is out.
class AppUpdateGate extends ConsumerWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider);
    if (update == null) return child;
    if (update.required) return _UpdateRequiredScreen(update: update);

    final tokens = JolTokens.of(context);
    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: 100,
          child: SafeArea(
            child: Material(
              color: tokens.surface,
              elevation: 6,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        update.latest == null
                            ? 'A new version of JOL is out.'
                            : 'JOL ${update.latest} is out.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (update.storeUrl != null)
                      TextButton(
                        onPressed: () => _openStore(update.storeUrl!),
                        child: const Text('Update'),
                      ),
                    // No tooltip: this sits above the app's navigator, where tooltips can't show.
                    IconButton(
                      icon: const Icon(Icons.close, semanticLabel: 'Not now'),
                      onPressed: () => ref.read(appUpdateProvider.notifier).dismiss(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen({required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.system_update_alt, size: 56, color: tokens.text),
              const SizedBox(height: 28),
              Text(
                'Time to update JOL',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                update.message ??
                    'This version of JOL is no longer supported. Update to keep '
                        'buying tickets and getting into events.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: 28),
              if (update.storeUrl != null)
                JolButton(
                  label: 'Update now',
                  expanded: true,
                  onPressed: () => _openStore(update.storeUrl!),
                ),
              const SizedBox(height: 12),
              Text(
                'You’re on version ${AppBuild.version}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openStore(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}
