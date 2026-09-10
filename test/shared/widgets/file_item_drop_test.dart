import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:virtual_desktop/core/constants.dart';
import 'package:virtual_desktop/core/error/failure.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/core/repositories/file_transfer_repository.dart';
import 'package:virtual_desktop/shared/widgets/file_item_drop.dart';

class _MockFileSystemRepository extends Mock implements FileSystemRepository {}

class _MockFileTransferRepository extends Mock
    implements FileTransferRepository {}

const _uid = 'user-1';

FileItem _report({required String ownerId, String? parentFolderId}) => FileItem(
  id: 'report-id',
  name: 'report.pdf',
  parentFolderId: parentFolderId,
  ownerId: ownerId,
  type: FileItemType.pdf,
  storageKey: 'users/$ownerId/report.pdf',
  size: 1024,
);

void main() {
  late _MockFileSystemRepository repo;
  late _MockFileTransferRepository transfers;

  setUpAll(() => registerFallbackValue(FileTransferMode.move));

  setUp(() {
    repo = _MockFileSystemRepository();
    transfers = _MockFileTransferRepository();
    when(
      () => repo.move(any(), any()),
    ).thenAnswer((_) async => const Right(unit));
    when(
      () => transfers.transfer(
        itemId: any(named: 'itemId'),
        fromShared: any(named: 'fromShared'),
        toShared: any(named: 'toShared'),
        destinationParentFolderId: any(named: 'destinationParentFolderId'),
        mode: any(named: 'mode'),
      ),
    ).thenAnswer((_) async => Right(_report(ownerId: sharedOwnerId)));
  });

  void verifyNoTransfer() => verifyNever(
    () => transfers.transfer(
      itemId: any(named: 'itemId'),
      fromShared: any(named: 'fromShared'),
      toShared: any(named: 'toShared'),
      destinationParentFolderId: any(named: 'destinationParentFolderId'),
      mode: any(named: 'mode'),
    ),
  );

  void verifyNothingMoved() {
    verifyNever(() => repo.move(any(), any()));
    verifyNoTransfer();
  }

  /// Stands in for a DragTarget's onAccept: taps a button that drops
  /// [item], then settles on whatever that opens.
  Future<void> drop(
    WidgetTester tester, {
    required FileItem item,
    String? sourceFolderName = 'Desktop',
    required String? destinationFolderId,
    String destinationFolderName = 'Projects',
    bool isSharedDestination = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmAndMoveDroppedItem(
                context: context,
                dragged: DraggedFileItem(
                  item: item,
                  sourceFolderName: sourceFolderName,
                ),
                destinationFolderId: destinationFolderId,
                destinationFolderName: destinationFolderName,
                isSharedDestination: isSharedDestination,
                fileSystemRepository: repo,
                transferRepository: transfers,
              ),
              child: const Text('drop'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('drop'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks first, naming the item and both folders', (tester) async {
    await drop(
      tester,
      item: _report(ownerId: _uid),
      destinationFolderId: 'projects-id',
    );

    expect(
      find.text('Move report.pdf from Desktop to Projects?'),
      findsOneWidget,
    );
    verifyNothingMoved();
  });

  testWidgets('Cancel leaves the item where it was', (tester) async {
    await drop(
      tester,
      item: _report(ownerId: _uid),
      destinationFolderId: 'projects-id',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNothingMoved();
  });

  testWidgets('dismissing the dialog is a Cancel too', (tester) async {
    await drop(
      tester,
      item: _report(ownerId: _uid),
      destinationFolderId: 'projects-id',
    );
    await tester.tapAt(const Offset(5, 5)); // the modal barrier
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    verifyNothingMoved();
  });

  testWidgets("Move within one tree goes through that tree's repository", (
    tester,
  ) async {
    await drop(
      tester,
      item: _report(ownerId: _uid),
      destinationFolderId: 'projects-id',
    );
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    verify(() => repo.move('report-id', 'projects-id')).called(1);
    verifyNoTransfer();
  });

  testWidgets('Move into Shared is a server-side transfer, in move mode', (
    tester,
  ) async {
    await drop(
      tester,
      item: _report(ownerId: _uid),
      destinationFolderId: null,
      destinationFolderName: 'Shared',
      isSharedDestination: true,
    );
    expect(
      find.text('Move report.pdf from Desktop to Shared?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    verify(
      () => transfers.transfer(
        itemId: 'report-id',
        fromShared: false,
        toShared: true,
        destinationParentFolderId: null,
        mode: FileTransferMode.move,
      ),
    ).called(1);
    verifyNever(() => repo.move(any(), any()));
  });

  testWidgets('Move out of Shared is a transfer the other way', (tester) async {
    await drop(
      tester,
      item: _report(ownerId: sharedOwnerId),
      sourceFolderName: 'Shared',
      destinationFolderId: 'projects-id',
    );
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    verify(
      () => transfers.transfer(
        itemId: 'report-id',
        fromShared: true,
        toShared: false,
        destinationParentFolderId: 'projects-id',
        mode: FileTransferMode.move,
      ),
    ).called(1);
    verifyNever(() => repo.move(any(), any()));
  });

  testWidgets('a drop into the folder the item is already in asks nothing', (
    tester,
  ) async {
    await drop(
      tester,
      item: _report(ownerId: _uid, parentFolderId: 'projects-id'),
      destinationFolderId: 'projects-id',
    );

    expect(find.byType(AlertDialog), findsNothing);
    verifyNothingMoved();
  });

  testWidgets('the two tree roots are different places', (tester) async {
    // Both roots are a null parent id — only the owner tells them apart.
    await drop(
      tester,
      item: _report(ownerId: sharedOwnerId),
      sourceFolderName: 'Shared',
      destinationFolderId: null,
      destinationFolderName: 'Desktop',
    );

    expect(
      find.text('Move report.pdf from Shared to Desktop?'),
      findsOneWidget,
    );
  });

  testWidgets('leaves out "from" when the source folder is unknown', (
    tester,
  ) async {
    await drop(
      tester,
      item: _report(ownerId: _uid, parentFolderId: 'somewhere-id'),
      sourceFolderName: null,
      destinationFolderId: 'projects-id',
    );

    expect(find.text('Move report.pdf to Projects?'), findsOneWidget);
  });

  testWidgets('a failed move says why', (tester) async {
    when(() => repo.move(any(), any())).thenAnswer(
      (_) async => const Left(
        FileSystemFailure(
          '"report.pdf" already exists in the destination folder.',
        ),
      ),
    );
    await drop(
      tester,
      item: _report(ownerId: _uid),
      destinationFolderId: 'projects-id',
    );
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Move failed: "report.pdf" already exists in the destination folder.',
      ),
      findsOneWidget,
    );
  });
}
