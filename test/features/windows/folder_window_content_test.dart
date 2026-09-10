import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:virtual_desktop/core/di/injector.dart';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/auth_repository.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';
import 'package:virtual_desktop/features/windows/bloc/window_bloc.dart';
import 'package:virtual_desktop/features/windows/presentation/folder_window_content.dart';
import 'package:virtual_desktop/shared/widgets/file_item_drop.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockFileSystemRepository extends Mock implements FileSystemRepository {}

class _MockStorageService extends Mock implements StorageService {}

const _projects = FileItem(
  id: 'projects-id',
  name: 'Projects',
  parentFolderId: null,
  ownerId: 'user-1',
  type: FileItemType.folder,
  storageKey: null,
  size: 0,
);

const _report = FileItem(
  id: 'report-id',
  name: 'report.pdf',
  parentFolderId: null,
  ownerId: 'user-1',
  type: FileItemType.pdf,
  storageKey: 'users/user-1/report.pdf',
  size: 1024,
);

void main() {
  late _MockFileSystemRepository repo;

  setUp(() {
    // Only UploadBloc's constructor reads it, and nothing here uploads.
    getIt.registerSingleton<AuthRepository>(_MockAuthRepository());
    repo = _MockFileSystemRepository();
    when(
      () => repo.watchFolder(any()),
    ).thenAnswer((_) => Stream.value(const <FileItem>[]));
    when(
      () => repo.move(any(), any()),
    ).thenAnswer((_) async => const Right(unit));
  });

  tearDown(() => getIt.reset());

  /// An empty "Projects" folder window, beside [incoming] to drag onto it.
  Future<void> pumpWindow(WidgetTester tester, DraggedFileItem incoming) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => WindowBloc(),
          child: Scaffold(
            body: Row(
              children: [
                Draggable<DraggedFileItem>(
                  data: incoming,
                  feedback: const SizedBox(width: 10, height: 10),
                  child: const SizedBox(
                    width: 80,
                    height: 80,
                    child: Text('incoming'),
                  ),
                ),
                Expanded(
                  child: FolderWindowContent(
                    windowId: 'projects-window',
                    rootFolder: _projects,
                    fileSystemRepository: repo,
                    storageService: _MockStorageService(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('an empty folder takes a drop, and asks before moving', (
    tester,
  ) async {
    await pumpWindow(
      tester,
      const DraggedFileItem(item: _report, sourceFolderName: 'Desktop'),
    );
    expect(find.text('This folder is empty'), findsOneWidget);

    await dragAndDrop(
      tester,
      tester.getCenter(find.text('incoming')),
      tester.getCenter(find.text('This folder is empty')),
    );
    expect(
      find.text('Move report.pdf from Desktop to Projects?'),
      findsOneWidget,
    );
    verifyNever(() => repo.move(any(), any()));

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    verify(() => repo.move('report-id', 'projects-id')).called(1);
  });

  testWidgets('a folder dropped into its own window is refused unasked', (
    tester,
  ) async {
    await pumpWindow(
      tester,
      const DraggedFileItem(item: _projects, sourceFolderName: 'Desktop'),
    );

    await dragAndDrop(
      tester,
      tester.getCenter(find.text('incoming')),
      tester.getCenter(find.text('This folder is empty')),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text(
        "A folder can't be moved into itself or one of its own subfolders.",
      ),
      findsOneWidget,
    );
    verifyNever(() => repo.move(any(), any()));
  });
}
