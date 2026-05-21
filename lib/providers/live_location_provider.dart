import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/bootstrap.dart';

class UserLocation {
  final String userId;
  final String? displayName;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime updatedAt;

  const UserLocation({
    required this.userId,
    this.displayName,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.updatedAt,
  });

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      userId: json['user_id'] as String,
      displayName: json['profiles'] != null
          ? (json['profiles'] as Map<String, dynamic>)['display_name'] as String?
          : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

final liveLocationProvider =
    Provider<LiveLocationService>((ref) => LiveLocationService(ref));

class LiveLocationService {
  final Ref _ref;
  StreamSubscription<Position>? _subscription;
  Timer? _uploadTimer;
  Position? _lastPosition;

  LiveLocationService(this._ref);

  void startTracking() {
    _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      _lastPosition = position;
    });

    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _uploadPosition();
    });

    _uploadPosition();
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  Future<void> _uploadPosition() async {
    final pos = _lastPosition;
    if (pos == null) return;

    final client = _ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await client.from('user_locations').upsert({
        'user_id': userId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  void dispose() {
    stopTracking();
  }
}

final allUserLocationsProvider =
    AsyncNotifierProvider<AllUserLocationsNotifier, List<UserLocation>>(
  AllUserLocationsNotifier.new,
);

class AllUserLocationsNotifier extends AsyncNotifier<List<UserLocation>> {
  RealtimeChannel? _channel;

  @override
  Future<List<UserLocation>> build() async {
    ref.onDispose(() => _channel?.unsubscribe());
    _subscribe();
    return _fetch();
  }

  Future<List<UserLocation>> _fetch() async {
    final client = ref.read(supabaseProvider);
    final cutoff =
        DateTime.now().subtract(const Duration(minutes: 30)).toUtc().toIso8601String();
    final data = await client
        .from('user_locations')
        .select('*, profiles(display_name)')
        .gte('updated_at', cutoff)
        .order('updated_at', ascending: false);
    return (data as List).map((e) => UserLocation.fromJson(e)).toList();
  }

  void _subscribe() {
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('admin-user-locations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_locations',
          callback: (_) async {
            state = AsyncData(await _fetch());
          },
        )
        .subscribe();
  }
}
