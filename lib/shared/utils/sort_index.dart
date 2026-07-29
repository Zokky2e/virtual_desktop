// lib/shared/utils/sort_index.dart

/// Computes a sortIndex placing an item between [before] and [after]
/// (either sibling, in file order). Pass null for an edge (start/end
/// of the list, or an empty folder).
double sortIndexBetween(double? before, double? after) {
  if (before == null && after == null) return 0;
  if (before == null) return after! - 1;
  if (after == null) return before + 1;
  return (before + after) / 2;
}
