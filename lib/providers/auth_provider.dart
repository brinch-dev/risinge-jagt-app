import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jagt_app/models/user_profile.dart';
import 'package:jagt_app/bootstrap.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
  UserProfileNotifier.new,
);

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  RealtimeChannel? _profileChannel;

  @override
  Future<UserProfile?> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    _subscribeToProfileChanges(user.id);
    ref.onDispose(() => _profileChannel?.unsubscribe());
    return _fetchProfile(user.id);
  }

  void _subscribeToProfileChanges(String userId) {
    final client = ref.read(supabaseProvider);
    _profileChannel = client
        .channel('my-profile')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (_) async {
            state = AsyncData(await _fetchProfile(userId));
          },
        )
        .subscribe();
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
    final client = ref.read(supabaseProvider);
    final data =
        await client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> refresh() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = AsyncData(await _fetchProfile(user.id));
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final client = ref.read(supabaseProvider);
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    await client.from('profiles').update(updates).eq('id', user.id);
    await refresh();
  }
}

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password, String name) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    if (response.user != null) {
      await _client.from('profiles').upsert({
        'id': response.user!.id,
        'email': email,
        'full_name': name,
        'display_name': name,
        'role': 'gaest',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> deleteAccount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('profiles').delete().eq('id', userId);
    await _client.rpc('delete_my_account');
    await _client.auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(supabaseProvider));
});
