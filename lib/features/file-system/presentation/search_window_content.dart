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
  final _controller = TextEditingController();
  List<FileItem> _results = [];
  bool _isSearching = false;

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final uid = getIt<AuthRepository>().currentUser!.uid;
    final result = await getIt<FileSystemRepository>().searchItems(
      uid,
      query.trim(),
    );
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _results = result.getOrElse((_) => []);
    });
  }

  @override
  void dispose() {
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
              onSubmitted: _runSearch,
              onChanged: _runSearch,
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
