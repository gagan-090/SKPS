import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';

/// Owner authentication. The app has exactly one account, created by hand in
/// the Supabase dashboard, so there is no sign-up path here.
class AuthRepository {
  const AuthRepository();

  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  String? get ownerId => currentUser?.id;

  bool get isLoggedIn => currentSession != null;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (error, stack) {
      throw AppException.from(error, stack);
    }
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => const AuthRepository());

/// Emits every sign-in / sign-out / token refresh. The router listens to this.
final StreamProvider<AuthState> authStateChangesProvider =
    StreamProvider<AuthState>(
      (Ref ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
    );
