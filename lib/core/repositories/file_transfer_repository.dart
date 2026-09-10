import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';
import '../models/file_item.dart';

enum FileTransferMode {
  /// Leaves the original in place.
  copy,

  /// Removes it from the source tree.
  move,
}

/// Moves or copies an item between the personal and shared trees.
///
/// Deliberately its own interface rather than a method on
/// [FileSystemRepository]: every method there is scoped to the one tree
/// its registration serves, and a transfer is the single operation that
/// spans both. Adding it there would have meant a `FileSystemRepository`
/// that can reach outside its own tree, which is exactly the confusion
/// the personal/shared registration split exists to prevent — and it
/// would have forced the same method onto the Firestore and fake
/// implementations, which have no notion of a second tree at all.
///
/// Backed by `POST /desktop/transfer`. The work happens server-side: the
/// bytes never travel through the client, which matters when the item is
/// one of the multi-gigabyte videos this app streams.
abstract class FileTransferRepository {
  /// Returns the item in its new home — a new record for a copy, the
  /// same id under a new owner for a move.
  ///
  /// [name] is honoured for copies only, so a paste can de-duplicate
  /// against the destination folder the way a within-tree paste does. A
  /// move keeps the item's own name and fails on a clash.
  Future<Either<Failure, FileItem>> transfer({
    required String itemId,
    required bool fromShared,
    required bool toShared,
    required String? destinationParentFolderId,
    required FileTransferMode mode,
    String? name,
  });
}
