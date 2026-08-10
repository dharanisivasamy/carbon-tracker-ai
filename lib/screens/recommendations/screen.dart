import 'dart:async';

import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/models/trip_model.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/services/api/api_client.dart';
import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:carbon_tracker/widgets/cards/app_card.dart';
import 'package:flutter/material.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  /// Recommendations fetched from GET /trips/recommendations, or null if
  /// they haven't loaded yet / the user is offline / the request failed.
  /// The UI always has [_local] to fall back on so this being null never
  /// means a blank screen.
  List<Map<String, dynamic>>? _serverItems;
  bool _loadingServer = true;
  String? _error;
  Timer? _tripRefreshTimer;

  @override
  void initState() {
    super.initState();
    TripRepository.instance.trips.addListener(_refreshAfterTripChange);
    _load();
  }

  @override
  void dispose() {
    _tripRefreshTimer?.cancel();
    TripRepository.instance.trips.removeListener(_refreshAfterTripChange);
    super.dispose();
  }

  /// A new locally saved or synchronised trip means the server insights may
  /// have changed. Debouncing coalesces repository updates during sync.
  void _refreshAfterTripChange() {
    _tripRefreshTimer?.cancel();
    _tripRefreshTimer = Timer(const Duration(milliseconds: 500), _load);
  }

  Future<void> _load() async {
    final token = await AuthService.instance.token;
    if (token == null) {
      // Not authenticated (or logged out mid-navigation): nothing to fetch,
      // fall back to the local, trip-derived suggestions below.
      if (mounted) setState(() => _loadingServer = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loadingServer = true;
        _error = null;
      });
    }
    try {
      final result = await ApiService.instance.recommendations(token);
      final rawList = result['data'];
      if (rawList is! List) {
        throw ApiException('Received an unexpected response from the server.');
      }
      final items = rawList.whereType<Map<String, dynamic>>().toList();
      if (mounted) setState(() => _serverItems = items);
    } catch (e) {
      logDebug('[RECOMMENDATIONS] Failed to load recommendations: $e');
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'Unable to load recommendations right now.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingServer = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: Text('Recommendations', style: AppTextStyles.title),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loadingServer ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ValueListenableBuilder<List<TripModel>>(
        valueListenable: TripRepository.instance.trips,
        builder: (context, trips, _) {
          // Loading state: only shown before we have anything at all
          // (neither server data nor a prior local render) to avoid a
          // spinner flashing over content on every background refresh.
          if (_loadingServer && _serverItems == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = _serverItems ?? _local(trips);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              if (_error != null) _ErrorBanner(message: _error!),
              if (items.isEmpty)
                const _EmptyRecommendations()
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['title'] as String?) ?? 'Recommendation',
                            style: AppTextStyles.title,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if ((item['description'] as String?)?.isNotEmpty ??
                              false)
                            Text(
                              item['description'] as String,
                              style: AppTextStyles.body,
                            ),
                          if ((item['reason'] as String?)?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              item['reason'] as String,
                              style: AppTextStyles.caption,
                            ),
                          ],
                          if (item['estimatedSavingKg'] case final num saving
                              when saving > 0) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Estimated potential saving: ${saving.toStringAsFixed(2)} kg CO₂',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  /// Offline / pre-existing fallback: derives a simple suggestion from
  /// locally stored trips when the backend recommendation can't be
  /// reached. This mirrors the logic that existed before server
  /// integration, kept intentionally rather than inventing a new fake
  /// backend response.
  List<Map<String, dynamic>> _local(List<TripModel> trips) {
    if (trips.isEmpty) {
      return [
        {
          'title': 'Track a few trips',
          'description': 'Add trips to receive personalised suggestions.',
          'reason': 'There is not enough trip data yet.',
        },
      ];
    }
    final highest = trips.reduce(
      (a, b) => a.carbonEmission > b.carbonEmission ? a : b,
    );
    return [
      {
        'title': 'Choose a lower-carbon option',
        'description':
            'Consider walking, cycling, bus, or train when practical.',
        'reason':
            'Your highest recorded trip was by ${highest.transportMode.label}.',
      },
    ];
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: InfoCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$message Showing suggestions based on your trips instead.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyRecommendations extends StatelessWidget {
  const _EmptyRecommendations();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
    child: Column(
      children: [
        const Icon(
          Icons.tips_and_updates_outlined,
          size: 56,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('No recommendations yet', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Add a few trips and check back for personalised suggestions.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
