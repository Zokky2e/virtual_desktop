import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import '../../core/error/failure.dart';

/// How long an operation runs before it is announced as underway. Anything
/// quicker only reports how it ended, so a small move doesn't flash a
/// progress message that is gone before it can be read.
const progressFeedbackDelay = Duration(milliseconds: 400);

/// Runs [operation], saying so while it runs if that takes long enough to
/// notice, and saying how it ended either way.
///
/// Moving a large folder between trees, or copying a large file, can run
/// for a good while after the confirmation dialog has closed. With nothing
/// on screen until the folder windows refreshed, it looked as if nothing
/// had happened at all.
///
/// Takes the [messenger] rather than a BuildContext: callers look it up
/// before their first await. The root messenger outlives the folder window
/// that started the operation, which may be closed before it finishes.
Future<Either<Failure, T>> runWithProgressFeedback<T>({
  required ScaffoldMessengerState? messenger,
  required String inProgress,
  required String succeeded,
  required String failurePrefix,
  required Future<Either<Failure, T>> Function() operation,
}) async {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? progress;
  final announce = Timer(progressFeedbackDelay, () {
    if (messenger == null || !messenger.mounted) return;
    progress = messenger.showSnackBar(
      _feedbackSnackBar(
        // Closed as soon as the operation ends, never timed out.
        duration: const Duration(days: 1),
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(inProgress)),
          ],
        ),
      ),
    );
  });

  final Either<Failure, T> result;
  try {
    result = await operation();
  } finally {
    announce.cancel();
    if (messenger != null && messenger.mounted) progress?.close();
  }

  if (messenger != null && messenger.mounted) {
    messenger.showSnackBar(
      _feedbackSnackBar(
        content: Text(
          result.match(
            (failure) => '$failurePrefix: ${failure.message}',
            (_) => succeeded,
          ),
        ),
      ),
    );
  }
  return result;
}

SnackBar _feedbackSnackBar({
  required Widget content,
  Duration duration = const Duration(seconds: 4),
}) => SnackBar(
  content: content,
  duration: duration,
  behavior: SnackBarBehavior.floating,
  // Clear of the 48px taskbar, like the desktop's other messages.
  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 64),
);
