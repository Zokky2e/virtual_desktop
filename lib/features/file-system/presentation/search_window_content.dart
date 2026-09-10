import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../desktop/presentation/desktop_icon.dart';

class SearchWindowContent extends StatefulWidget {
  const SearchWindowContent({super.key});

  @override
  State<SearchWindowContent> createState() => _SearchWindowContentState();
}

class _SearchWindowContentState extends State<SearchWindowContent> {
  /// How long typing has to pause before a request goes out. onChanged
  /// fires per keystroke, so without this "report" issued six searches.
  static const _debounce = Duration(milliseconds: 250);

  final _controller = TextEditingController();
  List<FileItem> _results = [];
  bool _isSearching = false;

  Timer? _debounceTimer;

  /// Incremented for every search started. A response whose id no longer
  /// matches is stale and gets dropped: requests can finish out of order,
  /// so without this, typing "report" could settle on the results for
  /// "rep" if the shorter query's response came back last.
  int _searchId = 0;

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    _debounceTimer?.cancel();
    final requestId = ++_searchId;

    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _results = [];
      });
      return;
    }
    final user = getIt<AuthRepository>().currentUser;
    // Signed out while the search window was open — nothing to search.
    if (user == null) {
      setState(() {
        _isSearching = false;
        _results = [];
      });
      return;
    }
    setState(() => _isSearching = true);
    final result = await getIt<FileSystemRepository>().searchItems(
      user.uid,
      query.trim(),
    );
    if (!mounted || requestId != _searchId) return;
    setState(() {
      _isSearching = false;
      _results = result.getOrElse((_) => []);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.primary,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: colorScheme.onPrimary),
              decoration: InputDecoration(
                hintText: 'Search files and folders...',
                hintStyle: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: colorScheme.onPrimary.withValues(alpha: 0.4),
                ),
              ),
              // Enter searches immediately; typing waits for the pause.
              onSubmitted: _runSearch,
              onChanged: _onQueryChanged,
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _controller.text.isEmpty
                          ? 'Type to search'
                          : 'No matches',
                      style: TextStyle(
                        color: colorScheme.onPrimary.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final item in _results)
                          DesktopIcon(
                            item: item,
                            iconColor: colorScheme.onPrimary,
                            isSelected: false,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
