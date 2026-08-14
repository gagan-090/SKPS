import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only error type that escapes the repository layer.
///
/// Screens and controllers show [message] directly to the owner, so it must
/// always be plain, non-technical English.
class AppException implements Exception {
  const AppException(this.message, {this.isNetwork = false, this.cause});

  final String message;

  /// True when the failure is connectivity related, so the UI can offer Retry
  /// rather than suggesting the data is wrong.
  final bool isNetwork;

  final Object? cause;

  static const String networkMessage =
      'No internet connection. Please check and retry.';

  /// Translates anything thrown by Supabase / dart:io into a readable failure.
  factory AppException.from(Object error, [StackTrace? _]) {
    if (error is AppException) return error;

    if (error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException ||
        error is HandshakeException) {
      return AppException(networkMessage, isNetwork: true, cause: error);
    }

    if (error is AuthApiException || error is AuthException) {
      return AppException(_authMessage(error as AuthException), cause: error);
    }

    if (error is PostgrestException) {
      return AppException(_postgrestMessage(error), cause: error);
    }

    if (error is StorageException) {
      return AppException('Storage error: ${error.message}', cause: error);
    }

    return AppException(
      'Something went wrong. Please try again.',
      cause: error,
    );
  }

  static String _authMessage(AuthException error) {
    final raw = error.message.toLowerCase();
    if (raw.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email not confirmed')) {
      return 'This email has not been confirmed yet.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (raw.contains('failed host lookup') || raw.contains('socket')) {
      return networkMessage;
    }
    return error.message;
  }

  static String _postgrestMessage(PostgrestException error) {
    switch (error.code) {
      case '23505':
        return 'This record already exists.';
      case '23503':
        return 'This record is linked to other data and cannot be changed.';
      case '23514':
        return 'Some of the details entered are not valid. Please check and retry.';
      case '42501':
      case 'PGRST301':
        return 'You are not allowed to do this. Please log in again.';
      default:
        final raw = error.message.toLowerCase();
        if (raw.contains('failed host lookup') ||
            raw.contains('socketexception') ||
            raw.contains('connection')) {
          return networkMessage;
        }
        return 'Could not reach the server. Please try again.';
    }
  }

  @override
  String toString() => 'AppException($message)';
}
