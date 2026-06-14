import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns a short, friendly message for display in SnackBars.
/// Pass [fallback] for the context-specific default when no pattern matches.
String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is PostgrestException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('insufficient') ||
        msg.contains('not enough') ||
        msg.contains('stock')) {
      return 'Not enough stock to complete this sale. Check current stock levels.';
    }
    if (msg.contains('already submitted') ||
        msg.contains('duplicate') && msg.contains('closing')) {
      return 'Cash closing for today has already been submitted.';
    }
    if (msg.contains('already decided') || msg.contains('not pending')) {
      return 'This request has already been decided.';
    }
    if (error.code == '23505') {
      return 'This record already exists. Please check for duplicates.';
    }
    if (error.code == '23503') {
      return 'A required record is missing. Please refresh and try again.';
    }
    if (error.code == '42501' ||
        msg.contains('permission denied') ||
        msg.contains('row-level security')) {
      return 'You don\'t have permission to do this. Contact the store owner.';
    }
    return fallback;
  }
  final str = error.toString().toLowerCase();
  if (str.contains('socketexception') ||
      str.contains('failed host lookup') ||
      str.contains('network is unreachable') ||
      str.contains('connection refused')) {
    return 'Cannot connect to the server. Check your internet connection.';
  }
  if (str.contains('timed out') ||
      str.contains('deadline exceeded') ||
      str.contains('timeout')) {
    return 'Connection timed out. Please try again.';
  }
  return fallback;
}
