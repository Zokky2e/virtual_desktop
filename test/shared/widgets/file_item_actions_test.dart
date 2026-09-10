import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:virtual_desktop/core/error/failure.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/core/repositories/file_transfer_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import 'package:virtual_desktop/features/file-system/clipboard/file_clipboard_cubit.dart';
import 'package:virtual_desktop/shared/widgets/file_item_actions.dart';
import 'package:virtual_desktop/shared/widgets/operation_feedback.dart';

class _MockFileSystemRepository extends Mock implements FileSystemRepository {}

class _MockStorageService extends Mock implements StorageService {}

class _MockFileTransferRepository extends Mock
    implements FileTransferRepository {}

const _film = FileItem(
  id: 'film-id',
  name: 'film.mkv',
  parentFolderId: null,
  ownerId: 'user-1',
  type: FileItemType.video,
  storageKey: 'film-id',
  size: 1024,
);

void main() {
  late _MockFileSystemRepository repo;
  late _MockStorageService storage;
  late _MockFileTransferRepository transfers;
  late FileClipboardCubit clipboard;

  setUpAll(() {
    registerFallbackValue(FileTransferMode.move);
    registerFallbackValue(FileItemType.other);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = _MockFileSystemRepository();
    storage = _MockStorageService();
    transfers = _MockFileTransferRepository();
    clipboard = FileClipboardCubit();
  });

  tearDown(() => clipboard.close());

  /// Taps a button that pastes whatever is on the clipboard.
  Future<void> paste(
    WidgetTester tester, {
    required String? destinationFolderId,
    required String destinationFolderName,
    bool isSharedDestination = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => pasteClipboardItem(
                context: context,
                clipboard: clipboard,
                destinationFolderId: destinationFolderId,
                destinationFolderName: destinationFolderName,
                fileSystemRepository: repo,
                storageService: storage,
                isSharedDestination: isSharedDestination,
                transferRepository: transfers,
              ),
              child: const Text('paste'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('paste'));
  }

  testWidgets('a cut pasted into Shared says it moved, and is used up', (
    tester,
  ) async {
    when(
      () => transfers.transfer(
        itemId: any(named: 'itemId'),
        fromShared: any(named: 'fromShared'),
        toShared: any(named: 'toShared'),
        destinationParentFolderId: any(named: 'destinationParentFolderId'),
        mode: any(named: 'mode'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async => const Right(_film));
    clipboard.cut(_film);

    await paste(
      tester,
      destinationFolderId: null,
      destinationFolderName: 'Shared',
      isSharedDestination: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Moved film.mkv to Shared'), findsOneWidget);
    expect(clipboard.state.isEmpty, isTrue);
  });

  testWidgets('a slow paste says it is underway until it is done', (
    tester,
  ) async {
    final finished = Completer<Either<Failure, Unit>>();
    when(() => repo.move(any(), any())).thenAnswer((_) => finished.future);
    clipboard.cut(_film);

    await paste(
      tester,
      destinationFolderId: 'watched-id',
      destinationFolderName: 'Watched',
    );
    await tester.pump(progressFeedbackDelay);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Moving film.mkv to Watched…'), findsOneWidget);

    finished.complete(const Right(unit));
    await tester.pumpAndSettle();

    expect(find.text('Moving film.mkv to Watched…'), findsNothing);
    expect(find.text('Moved film.mkv to Watched'), findsOneWidget);
  });

  testWidgets('a cut that fails says why, and stays on the clipboard', (
    tester,
  ) async {
    when(() => repo.move(any(), any())).thenAnswer(
      (_) async => const Left(
        FileSystemFailure(
          '"film.mkv" already exists in the destination folder.',
        ),
      ),
    );
    clipboard.cut(_film);

    await paste(
      tester,
      destinationFolderId: 'watched-id',
      destinationFolderName: 'Watched',
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Move failed: "film.mkv" already exists in the destination folder.',
      ),
      findsOneWidget,
    );
    expect(clipboard.state.isEmpty, isFalse);
  });

  testWidgets(
    'a copy within a tree says it copied, and stays on the clipboard',
    (tester) async {
      when(
        () => repo.nameExistsInFolder(
          ownerId: any(named: 'ownerId'),
          parentFolderId: any(named: 'parentFolderId'),
          name: any(named: 'name'),
        ),
      ).thenAnswer((_) async => const Right(false));
      when(
        () => storage.downloadFile(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList([1, 2, 3])));
      when(
        () => storage.uploadFile(
          bytes: any(named: 'bytes'),
          fileName: any(named: 'fileName'),
          mimeType: any(named: 'mimeType'),
          ownerId: any(named: 'ownerId'),
          parentFolderId: any(named: 'parentFolderId'),
        ),
      ).thenAnswer((_) async => const Right('copy-id'));
      when(
        () => repo.createFile(
          name: any(named: 'name'),
          parentFolderId: any(named: 'parentFolderId'),
          ownerId: any(named: 'ownerId'),
          type: any(named: 'type'),
          storageKey: any(named: 'storageKey'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => const Right(_film));
      clipboard.copy(_film);

      await paste(
        tester,
        destinationFolderId: 'watched-id',
        destinationFolderName: 'Watched',
      );
      await tester.pumpAndSettle();

      expect(find.text('Copied film.mkv to Watched'), findsOneWidget);
      expect(clipboard.state.isEmpty, isFalse);
      verify(
        () => repo.createFile(
          name: 'film.mkv',
          parentFolderId: 'watched-id',
          ownerId: 'user-1',
          type: FileItemType.video,
          storageKey: 'copy-id',
          size: 3,
        ),
      ).called(1);
    },
  );
}
