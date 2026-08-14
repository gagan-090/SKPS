import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/repositories/auth_repository.dart';

/// Login form state. Errors are already human readable by the time they land
/// here — the repository does the translating.
class LoginState {
  const LoginState({
    this.submitting = false,
    this.errorMessage,
    this.infoMessage,
  });

  final bool submitting;
  final String? errorMessage;
  final String? infoMessage;

  LoginState copyWith({
    bool? submitting,
    String? errorMessage,
    String? infoMessage,
    bool clearMessages = false,
  }) {
    return LoginState(
      submitting: submitting ?? this.submitting,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearMessages ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void clearMessages() {
    if (state.errorMessage == null && state.infoMessage == null) return;
    state = state.copyWith(clearMessages: true);
  }

  /// Returns true on success so the screen can navigate.
  Future<bool> signIn({required String email, required String password}) async {
    if (state.submitting) return false;
    state = const LoginState(submitting: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = const LoginState();
      return true;
    } on AppException catch (error) {
      state = LoginState(errorMessage: error.message);
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (state.submitting) return;
    state = const LoginState(submitting: true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      state = const LoginState(
        infoMessage: 'Password reset link sent. Please check your inbox.',
      );
    } on AppException catch (error) {
      state = LoginState(errorMessage: error.message);
    }
  }
}

final NotifierProvider<LoginController, LoginState> loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);
