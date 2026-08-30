import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads a required key from the loaded `.env`, failing with the key's name
/// instead of a bare null-check error.
///
/// `.env` is git-ignored, so a fresh clone starts with the file missing or
/// half-filled. `dotenv.env['API_BASE_URL']!` turns that into a
/// "Null check operator used on a null value" thrown from deep inside
/// [setupDependencies], which says nothing about which key is missing.
String requireEnv(String key) {
  final value = dotenv.env[key];
  if (value == null || value.isEmpty) {
    throw StateError(
      'Missing required .env key "$key". Add it to the .env file at the '
      'project root (see CLAUDE.md — the file is git-ignored, so a fresh '
      'clone has to create it).',
    );
  }
  return value;
}

/// Reads an optional key — returns null when absent or empty, so callers can
/// pass it straight to a nullable parameter.
String? optionalEnv(String key) {
  final value = dotenv.env[key];
  return (value == null || value.isEmpty) ? null : value;
}
