import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:virtual_desktop/core/constants.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/features/desktop/presentation/desktop_icon_grid.dart';
import 'package:virtual_desktop/shared/widgets/file_item_drop.dart';

class _MockFileSystemRepository extends Mock implements FileSystemRepository {}

FileItem _file(
  String name, {
  String ownerId = 'user-1',
  String? parentFolderId,
  double sortIndex = 0,
}) => FileItem(
  id: '$name-id',
  name: name,
  parentFolderId: parentFolderId,
  ownerId: ownerId,
  type: FileItemType.pdf,
  storageKey: 'users/$ownerId/$name',
  size: 1024,
  sortIndex: sortIndex,
);

void main() {
  late _MockFileSystemRepository repo;

  setUp(() {
    repo = _MockFileSystemRepository();
    when(
      () => repo.move(any(), any()),
    ).thenAnswer((_) async => const Right(unit));
    when(
      () => repo.reorder(
        itemId: any(named: 'itemId'),
        newSortIndex: any(named: 'newSortIndex'),
      ),
    ).thenAnswer((_) async => const Right(unit));
  });

  void verifyNoReorder() => verifyNever(
    () => repo.reorder(
      itemId: any(named: 'itemId'),
      newSortIndex: any(named: 'newSortIndex'),
    ),
  );

  /// The desktop root holding a.pdf and b.pdf, beside an icon from
  /// somewhere else that can be dragged onto it.
  Future<void> pumpDesktop(
    WidgetTester tester, {
    DraggedFileItem? outsider,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (outsider != null)
                Draggable<DraggedFileItem>(
                  data: outsider,
                  feedback: const SizedBox(width: 10, height: 10),
                  child: const SizedBox(
                    width: 80,
                    height: 80,
                    child: Text('outsider'),
                  ),
                ),
              Expanded(
                child: DesktopIconGrid(
                  items: [
                    _file('a.pdf', sortIndex: 0),
                    _file('b.pdf', sortIndex: 1),
                  ],
                  containerFolderId: null,
                  fileSystemRepository: repo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Presses at [from], drags past the touch slop, and lets go at [to].
  Future<void> dragAndDrop(WidgetTester tester, Offset from, Offset to) async {
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('an icon let go over its own slot stays where it is', (
    tester,
  ) async {
    await pumpDesktop(tester);
    final a = tester.getCenter(find.text('a.pdf'));

    await dragAndDrop(tester, a, a);

    expect(find.byType(AlertDialog), findsNothing);
    verifyNoReorder();
    verifyNever(() => repo.move(any(), any()));
  });

  testWidgets('a drop onto a sibling reorders, without asking', (tester) async {
    await pumpDesktop(tester);

    await dragAndDrop(
      tester,
      tester.getCenter(find.text('b.pdf')),
      tester.getCenter(find.text('a.pdf')),
    );

    expect(find.byType(AlertDialog), findsNothing);
    verify(
      () => repo.reorder(
        itemId: 'b.pdf-id',
        newSortIndex: any(named: 'newSortIndex'),
      ),
    ).called(1);
    verifyNever(() => repo.move(any(), any()));
  });

  testWidgets('a drop from another folder asks, and moves on confirm', (
    tester,
  ) async {
    await pumpDesktop(
      tester,
      outsider: DraggedFileItem(
        item: _file('c.pdf', parentFolderId: 'projects-id'),
        sourceFolderName: 'Projects',
      ),
    );

    await dragAndDrop(
      tester,
      tester.getCenter(find.text('outsider')),
      tester.getCenter(find.text('a.pdf')),
    );
    expect(find.text('Move c.pdf from Projects to Desktop?'), findsOneWidget);
    verifyNever(() => repo.move(any(), any()));

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    verify(() => repo.move('c.pdf-id', null)).called(1);
    verifyNoReorder();
  });

  testWidgets('a shared-root item is moved, not reordered into the desktop', (
    tester,
  ) async {
    // Its parent id is null, the same as the desktop root's.
    await pumpDesktop(
      tester,
      outsider: DraggedFileItem(
        item: _file('c.pdf', ownerId: sharedOwnerId),
        sourceFolderName: 'Shared',
      ),
    );

    await dragAndDrop(
      tester,
      tester.getCenter(find.text('outsider')),
      tester.getCenter(find.text('a.pdf')),
    );
    expect(find.text('Move c.pdf from Shared to Desktop?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNoReorder();
    verifyNever(() => repo.move(any(), any()));
  });
}
