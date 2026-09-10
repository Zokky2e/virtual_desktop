/// Sentinel `owner_id` the backend stores for every item in the shared
/// tree — mirrors `SHARED_OWNER_ID` in `../virtual-api/app/constants.py`.
///
/// Deliberately *not* `sharedInstanceName` from `core/di/injector.dart`,
/// even though the two currently spell the same string. That one is a
/// `get_it` registration key: renaming it is a purely client-side
/// refactor. This one is a value the server persists and matches rows on.
/// Reusing the DI key here meant a client-side rename would silently
/// change the `ownerId` written by `createFile` — harmless only for as
/// long as `ApiFileSystemRepository` keeps ignoring it.
const sharedOwnerId = 'shared';
