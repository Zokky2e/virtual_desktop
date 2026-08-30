// Project-aware static scanner for the virtual_desktop Flutter app.
//
// Complements `flutter analyze`: the analyzer knows Dart, this knows the
// conventions in CLAUDE.md (layering, DI instance names, platform-conditional
// files) and the leak/crash shapes this codebase is exposed to.
//
//   dart run tool/scan.dart              # human-readable report
//   dart run tool/scan.dart --json       # machine-readable, for agents
//   dart run tool/scan.dart --analyze    # also run + merge `flutter analyze`
//   dart run tool/scan.dart --only=arch  # arch|platform|lifecycle|runtime|hygiene
//
// Exit code is 1 when any high-severity finding is present, else 0.

import 'dart:convert';
import 'dart:io';

const _severityOrder = {'high': 0, 'medium': 1, 'low': 2};

class Finding {
  Finding(
    this.rule,
    this.group,
    this.severity,
    this.file,
    this.line,
    this.message, {
    this.hint,
  });

  final String rule;
  final String group;
  final String severity;
  final String file;
  final int line;
  final String message;
  final String? hint;

  Map<String, dynamic> toJson() => {
    'rule': rule,
    'group': group,
    'severity': severity,
    'file': file,
    'line': line,
    'message': message,
    if (hint != null) 'hint': hint,
  };
}

final List<Finding> findings = [];

void add(
  String rule,
  String group,
  String severity,
  String file,
  int line,
  String message, {
  String? hint,
}) {
  findings.add(Finding(rule, group, severity, file, line, message, hint: hint));
}

/// Types that own an OS/engine resource and must be released.
const _disposables = {
  'AnimationController',
  'TextEditingController',
  'ScrollController',
  'PageController',
  'TabController',
  'FocusNode',
  'StreamSubscription',
  'StreamController',
  'Timer',
  'VideoPlayerController',
  'VlcPlayerController',
  'AudioPlayer',
  'OverlayEntry',
  'Ticker',
};

String _rel(String path) => path.replaceAll(r'\', '/');

bool _isPlatformVariant(String path) {
  final name = _rel(path).split('/').last;
  return name.endsWith('_web.dart') ||
      name.endsWith('_desktop.dart') ||
      name.endsWith('_io.dart') ||
      name.endsWith('_stub.dart');
}

/// Strips `//` line comments so rules do not fire on prose. Crude but
/// sufficient: it does not track strings containing `//`, which here are URLs
/// and match no rule below.
String _stripComment(String line) {
  final i = line.indexOf('//');
  return i == -1 ? line : line.substring(0, i);
}

/// Body of the method whose signature matches [signature], found by brace
/// counting from the opening brace. Empty when the method is absent.
String _methodBody(String source, RegExp signature) {
  final m = signature.firstMatch(source);
  if (m == null) return '';
  var i = source.indexOf('{', m.end - 1);
  if (i == -1) return '';
  final start = i;
  var depth = 0;
  for (; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return source.substring(start);
}

// ---------------------------------------------------------------------------
// arch — the layering rules in CLAUDE.md "Conventions to preserve"
// ---------------------------------------------------------------------------

final _importRe = RegExp('^\\s*(?:import|export)\\s+[\'"]([^\'"]+)[\'"]');
// Same pattern, applied to a whole file rather than a single line.
final _importReMultiline = RegExp(
  '^\\s*(?:import|export)\\s+[\'"]([^\'"]+)[\'"]',
  multiLine: true,
);
final _instanceNameRe = RegExp('instanceName:\\s*[\'"](\\w+)[\'"]');

void checkArchitecture(String path, List<String> lines) {
  final rel = _rel(path);
  final isInjector = rel.endsWith('core/di/injector.dart');

  for (var i = 0; i < lines.length; i++) {
    final line = _stripComment(lines[i]);
    final importMatch = _importRe.firstMatch(line);

    if (importMatch != null) {
      final target = importMatch.group(1)!;

      // Convention 1: UI and BLoCs depend on interfaces, never on a concrete
      // provider implementation.
      final isUpperLayer =
          rel.startsWith('lib/features/') || rel.startsWith('lib/app/');
      if (isUpperLayer && target.contains('core/providers/')) {
        add(
          'arch/provider-import-in-upper-layer',
          'arch',
          'high',
          rel,
          i + 1,
          'Imports the concrete provider `$target` from the UI/BLoC layer.',
          hint:
              'Depend on the interface in core/repositories or core/services '
              'and resolve it through get_it, so swapping providers stays a '
              'DI-only change.',
        );
      }

      // Convention 2: repository and storage-service implementations never
      // call each other; both sit on the shared API clients.
      if (rel.contains('core/providers/')) {
        final inRepo = rel.contains('/repositories/');
        final inSvc = rel.contains('/services/');
        if (inRepo &&
            target.contains('/services/') &&
            !target.contains('core/services/')) {
          add(
            'arch/repo-imports-service-impl',
            'arch',
            'high',
            rel,
            i + 1,
            'Repository implementation imports a storage-service implementation.',
            hint:
                'Both should depend on the shared client (ApiClient/FilesApi/'
                'FoldersApi) instead.',
          );
        }
        if (inSvc &&
            target.contains('/repositories/') &&
            !target.contains('core/repositories/')) {
          add(
            'arch/service-imports-repo-impl',
            'arch',
            'high',
            rel,
            i + 1,
            'Storage-service implementation imports a repository implementation.',
            hint:
                'Both should depend on the shared client (ApiClient/FilesApi/'
                'FoldersApi) instead.',
          );
        }
      }
    }

    // Hardcoded get_it instance names drift from the constants in injector.dart
    // and silently resolve the wrong tree.
    if (!isInjector) {
      final named = _instanceNameRe.firstMatch(line);
      if (named != null) {
        add(
          'arch/hardcoded-instance-name',
          'arch',
          'medium',
          rel,
          i + 1,
          "Hardcoded get_it instanceName '${named.group(1)}'.",
          hint:
              'Use the sharedInstanceName / wallpaperInstanceName constants '
              'from core/di/injector.dart, or take the repository via '
              'constructor injection the way FolderWindowContent does.',
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// platform — web vs Windows build integrity
// ---------------------------------------------------------------------------

final _declRe = RegExp(
  r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+)*'
  r'(?:class|mixin|enum|typedef)\s+(\w+)',
  multiLine: true,
);
final _topLevelFnRe = RegExp(
  r'^[A-Za-z_][\w<>,\s?\[\]]*?\s(\w+)\s*\(',
  multiLine: true,
);
const _fnKeywords = {'if', 'for', 'while', 'switch', 'return', 'assert'};

/// Public top-level declarations, used to compare platform variants.
Set<String> _publicTopLevelSymbols(String source) {
  final symbols = <String>{};
  for (final m in _declRe.allMatches(source)) {
    symbols.add(m.group(1)!);
  }
  for (final m in _topLevelFnRe.allMatches(source)) {
    final name = m.group(1)!;
    if (_fnKeywords.contains(name)) continue;
    symbols.add(name);
  }
  return symbols.where((s) => !s.startsWith('_')).toSet();
}

final _platformImportRe = RegExp(
  '^\\s*import\\s+[\'"](dart:io|dart:html|package:web/[^\'"]+)[\'"]',
);
final _exportStmtRe = RegExp(r'export\s+([^;]*);', multiLine: true);
final _dartRefRe = RegExp('[\'"]([^\'"]+\\.dart)[\'"]');

/// A platform-only import awaiting the reachability check below: whether the
/// *other* platform's build can actually reach this file.
class _PlatformImport {
  _PlatformImport(this.file, this.line, this.api);

  final String file;
  final int line;
  final String api;
}

final List<_PlatformImport> _platformImports = [];

/// `lib/a/b.dart` <- every file that imports or exports it. Conditional
/// exports count: that is exactly how a `_web` variant pulls in web-only code.
Map<String, Set<String>> buildImporterGraph(Map<String, String> sources) {
  final graph = <String, Set<String>>{};
  for (final entry in sources.entries) {
    final from = entry.key;
    final dir = from.substring(0, from.lastIndexOf('/'));
    for (final m in _importReMultiline.allMatches(entry.value)) {
      final target = m.group(1)!;
      String? resolved;
      if (target.startsWith('package:virtual_desktop/')) {
        resolved = 'lib/${target.substring('package:virtual_desktop/'.length)}';
      } else if (!target.contains(':')) {
        resolved = _normalize('$dir/$target');
      }
      if (resolved == null || !sources.containsKey(resolved)) continue;
      graph.putIfAbsent(resolved, () => <String>{}).add(from);
    }
  }
  return graph;
}

String _normalize(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return parts.join('/');
}

/// Walks the import graph upward from [file]. Returns true when some path
/// reaches a root without passing through a variant that gates it off the
/// platform in question — i.e. the other target really can compile this file.
bool _reachableUngated(
  String file,
  Set<String> gateSuffixes,
  Map<String, Set<String>> graph,
) {
  final seen = <String>{};
  final queue = <String>[...?graph[file]];
  if (queue.isEmpty) return false; // nothing imports it; not in either build
  while (queue.isNotEmpty) {
    final node = queue.removeLast();
    if (!seen.add(node)) continue;
    if (gateSuffixes.any(node.endsWith)) continue; // this branch is guarded
    final importers = graph[node];
    if (importers == null || importers.isEmpty) return true; // hit a root
    queue.addAll(importers);
  }
  return false;
}

void reportPlatformImports(Map<String, Set<String>> graph) {
  for (final candidate in _platformImports) {
    final isIo = candidate.api == 'dart:io';
    final gates = isIo
        ? const {'_desktop.dart', '_io.dart'}
        : const {'_web.dart'};
    if (!_reachableUngated(candidate.file, gates, graph)) continue;

    final base = candidate.file.split('/').last.replaceAll('.dart', '');
    if (isIo) {
      // Empirically `flutter build web` accepts the import; the cost is
      // deferred to runtime, where any dart:io call throws.
      add(
        'platform/io-reachable-from-web',
        'platform',
        'medium',
        candidate.file,
        candidate.line,
        'Imports `dart:io` and is reachable from the web entrypoint with no '
            '_desktop/_io variant gating it.',
        hint:
            'The web build tolerates the import, so this is safe only while a '
            'runtime kIsWeb guard keeps every dart:io call off the web path. '
            'Confirm that guard exists, or split into ${base}_io.dart behind a '
            'conditional export so the compiler enforces it.',
      );
    } else {
      add(
        'platform/web-only-reachable-from-windows',
        'platform',
        'high',
        candidate.file,
        candidate.line,
        'Imports `${candidate.api}` and is reachable from the Windows '
            'entrypoint with no _web variant gating it.',
        hint:
            'package:web compiles only for web — the Windows build fails here. '
            'Move it behind a conditional export (${base}_web.dart / '
            '${base}_desktop.dart).',
      );
    }
  }
}

void checkPlatform(String path, List<String> lines, String source) {
  final rel = _rel(path);

  // A platform-only import in a file with no _web/_desktop/_io/_stub suffix
  // compiles on one target and breaks the other — but only if that target can
  // reach it. Collect now, resolve against the import graph once all files are
  // read.
  for (var i = 0; i < lines.length; i++) {
    final m = _platformImportRe.firstMatch(_stripComment(lines[i]));
    if (m == null) continue;
    if (_isPlatformVariant(rel)) continue;
    if (source.contains('if (dart.library')) continue;
    _platformImports.add(_PlatformImport(rel, i + 1, m.group(1)!));
  }

  // Conditional-export barrels: every variant must exist and expose the same
  // public API, or the other platform fails to compile.
  if (!source.contains('if (dart.library')) return;
  for (final m in _exportStmtRe.allMatches(source)) {
    final body = m.group(1)!;
    if (!body.contains('dart.library')) continue;
    final refs = _dartRefRe
        .allMatches(body)
        .map((r) => r.group(1)!)
        .toList();
    final dir = File(path).parent.path;
    final present = <String, String>{};
    for (final ref in refs) {
      final variant = File('$dir/$ref');
      if (!variant.existsSync()) {
        add(
          'platform/missing-variant',
          'platform',
          'high',
          rel,
          1,
          'Conditional export references `$ref`, which does not exist.',
        );
        continue;
      }
      present[ref] = variant.readAsStringSync();
    }
    if (present.length < 2) continue;

    final symbolsPer = {
      for (final e in present.entries) e.key: _publicTopLevelSymbols(e.value),
    };
    final union = symbolsPer.values.expand((s) => s).toSet();
    for (final symbol in union) {
      final missing = symbolsPer.entries
          .where((e) => !e.value.contains(symbol))
          .map((e) => e.key)
          .toList();
      if (missing.isEmpty || missing.length == symbolsPer.length) continue;
      add(
        'platform/variant-api-drift',
        'platform',
        'high',
        rel,
        1,
        '`$symbol` is exported by some platform variants but missing from '
            '${missing.join(', ')}.',
        hint:
            'Every variant behind a conditional export must expose the same '
            'public names, or the target that resolves to the incomplete '
            'variant fails to compile.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// lifecycle — leaks that outlive a closed window
// ---------------------------------------------------------------------------

final _stateRe = RegExp(r'extends\s+State<');
final _blocRe = RegExp(r'extends\s+(Bloc|Cubit)<');
final _disposeSigRe = RegExp(r'void\s+dispose\s*\(\s*\)');
final _closeSigRe = RegExp(r'Future<void>\s+close\s*\(\s*\)');
final _classHeaderRe = RegExp(
  r'^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+)*class\s+(\w+)([^{]*)\{',
  multiLine: true,
);
final _disposableFieldRe = RegExp(
  '^\\s{2}(?:late\\s+)?(?:final\\s+)?(${_disposables.join('|')})'
  '(?:<[^>]*>)?\\??\\s+(\\w+)\\s*[;=]',
  multiLine: true,
);
// Any field, disposable-typed or not — needed to spot a field that owns
// another one and releases it on our behalf.
final _anyFieldRe = RegExp(
  r'^\s{2}(?:late\s+)?(?:final\s+)?[\w<>,\s?\[\]]+\s(\w+)\s*[;=]',
  multiLine: true,
);

/// One class declaration: its `extends` clause and its body, brace-matched.
/// Dart has no nested classes, so every match here is top level.
class _ClassChunk {
  _ClassChunk(this.name, this.header, this.body, this.bodyOffset);

  final String name;
  final String header;
  final String body;
  final int bodyOffset;
}

List<_ClassChunk> _classChunks(String source) {
  final chunks = <_ClassChunk>[];
  for (final m in _classHeaderRe.allMatches(source)) {
    final open = m.end - 1;
    var depth = 0;
    var end = source.length - 1;
    for (var i = open; i < source.length; i++) {
      final c = source[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          end = i;
          break;
        }
      }
    }
    chunks.add(
      _ClassChunk(
        m.group(1)!,
        m.group(2)!,
        source.substring(open, end + 1),
        open,
      ),
    );
  }
  return chunks;
}

/// The right-hand side of `field = ...`, up to the terminating `;`.
String _assignmentExpr(String body, String field) {
  final m = RegExp('(?<![\\w.])$field\\s*=(?!=)').firstMatch(body);
  if (m == null) return '';
  final end = body.indexOf(';', m.end);
  return end == -1 ? '' : body.substring(m.end, end);
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

void checkLifecycle(String path, List<String> lines, String source) {
  final rel = _rel(path);

  for (final cls in _classChunks(source)) {
    final isState = _stateRe.hasMatch(cls.header);
    final isBloc = _blocRe.hasMatch(cls.header);
    if (!isState && !isBloc) continue;

    final teardown = isState
        ? _methodBody(cls.body, _disposeSigRe)
        : _methodBody(cls.body, _closeSigRe);
    final teardownName = isState ? 'dispose()' : 'close()';

    final disposables = <String, String>{}; // name -> type
    final offsets = <String, int>{}; // name -> offset in source
    for (final m in _disposableFieldRe.allMatches(cls.body)) {
      disposables[m.group(2)!] = m.group(1)!;
      offsets[m.group(2)!] = cls.bodyOffset + m.start;
    }

    // Fields the teardown does touch — one of these may own an untouched one.
    final releasedOwners = _anyFieldRe
        .allMatches(cls.body)
        .map((m) => m.group(1)!)
        .where((f) => teardown.contains(f))
        .toList();

    for (final entry in disposables.entries) {
      final name = entry.key;
      final type = entry.value;
      final line = _lineOf(source, offsets[name]!);
      final call = type == 'StreamSubscription' || type == 'Timer'
          ? '$name?.cancel()'
          : '$name.dispose()';

      if (teardown.isEmpty) {
        add(
          'lifecycle/missing-teardown',
          'lifecycle',
          'high',
          rel,
          line,
          '${cls.name} holds a `$type $name` but never overrides $teardownName.',
          hint:
              'Windows in this app open and close repeatedly, so an unreleased '
              '$type leaks once per open, and a live subscription keeps firing '
              'into a dead widget.',
        );
        continue;
      }
      if (teardown.contains(name)) continue;

      // Ownership transfer: `_playback = Wrapper(controller: _controller)`
      // where _playback.dispose() is called. Real, but worth an eyeball.
      final owner = releasedOwners.firstWhere(
        (o) => RegExp('(?<![\\w.])$name(?![\\w])')
            .hasMatch(_assignmentExpr(cls.body, o)),
        orElse: () => '',
      );
      if (owner.isNotEmpty) {
        add(
          'lifecycle/indirect-release',
          'lifecycle',
          'low',
          rel,
          line,
          '`$type $name` is released only indirectly, via `$owner` in '
              '$teardownName.',
          hint:
              'Confirm $owner\'s own teardown really disposes $name; if it '
              'ever stops doing so, this leaks silently.',
        );
        continue;
      }

      add(
        'lifecycle/field-not-released',
        'lifecycle',
        'high',
        rel,
        line,
        '`$type $name` is never released in ${cls.name}.$teardownName.',
        hint: 'Call $call in $teardownName.',
      );
    }

    // A .listen() whose subscription is not stored cannot be cancelled at all.
    if (isBloc &&
        cls.body.contains('.listen(') &&
        !cls.body.contains('StreamSubscription')) {
      add(
        'lifecycle/unstored-subscription',
        'lifecycle',
        'high',
        rel,
        _lineOf(source, cls.bodyOffset + cls.body.indexOf('.listen(')),
        '${cls.name} subscribes with `.listen(` without keeping the '
            'StreamSubscription.',
        hint:
            'Store it in a field and cancel it in close(); an orphan '
            'subscription emits into a closed bloc and throws "Cannot add new '
            'events after calling close".',
      );
    }

    if (isState &&
        teardown.isNotEmpty &&
        !teardown.contains('super.dispose()')) {
      add(
        'lifecycle/missing-super-dispose',
        'lifecycle',
        'medium',
        rel,
        _lineOf(source, cls.bodyOffset + cls.body.indexOf(teardown)),
        '${cls.name}.dispose() does not call super.dispose().',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// runtime — shapes that throw in production, not in analysis
// ---------------------------------------------------------------------------

final _envBangRe = RegExp(r'dotenv\.env\[[^\]]+\]!');
final _printRe = RegExp(r'(?<![\w.])print\s*\(');
final _todoRe = RegExp(r'\b(TODO|FIXME|HACK|XXX)\b');

void checkRuntime(String path, List<String> lines) {
  final rel = _rel(path);
  for (var i = 0; i < lines.length; i++) {
    final line = _stripComment(lines[i]);

    if (_envBangRe.hasMatch(line)) {
      add(
        'runtime/env-force-unwrap',
        'runtime',
        'medium',
        rel,
        i + 1,
        'Force-unwraps a .env value — a missing key throws a null-check error '
            'at startup with no usable message.',
        hint:
            'Read it into a local and throw a StateError naming the missing '
            'key; .env is git-ignored, so a fresh clone hits this first.',
      );
    }

    if (line.contains('currentUser!')) {
      add(
        'runtime/current-user-force-unwrap',
        'runtime',
        'medium',
        rel,
        i + 1,
        'Force-unwraps `currentUser` — throws if the token expired or a '
            'sign-out raced this call.',
        hint: 'Guard on null and route back to login instead.',
      );
    }

    if (_printRe.hasMatch(line)) {
      add('hygiene/print', 'hygiene', 'low', rel, i + 1, 'Leftover print() call.');
    }

    final todo = _todoRe.firstMatch(lines[i]);
    if (todo != null) {
      add(
        'hygiene/todo',
        'hygiene',
        'low',
        rel,
        i + 1,
        '${todo.group(1)}: ${lines[i].trim()}',
      );
    }
  }
}

// ---------------------------------------------------------------------------

final _analyzerLineRe = RegExp(
  r'^\s*(\w+)\s+-\s+(.*?)\s+-\s+(\S+):(\d+):\d+\s+-\s+(\S+)$',
);

/// Lints the analyzer files under `info` that describe a real crash path, not
/// a style preference. Using a BuildContext after an await throws once the
/// widget is gone, which in this app happens every time a window is closed
/// during a network call.
const _analyzerSeverityOverride = {
  'use_build_context_synchronously': 'medium',
  'unawaited_futures': 'medium',
  'close_sinks': 'medium',
  'cancel_subscriptions': 'medium',
};

Future<List<Finding>> runFlutterAnalyze() async {
  final out = <Finding>[];
  final result = await Process.run(
    'flutter',
    ['analyze', '--no-pub'],
    runInShell: true,
  );
  for (final line in const LineSplitter().convert('${result.stdout}')) {
    final m = _analyzerLineRe.firstMatch(line);
    if (m == null) continue;
    final level = m.group(1)!;
    final lint = m.group(5)!;
    final severity = level == 'error'
        ? 'high'
        : (level == 'warning'
              ? 'medium'
              : _analyzerSeverityOverride[lint] ?? 'low');
    out.add(
      Finding(
        'analyzer/$lint',
        'analyzer',
        severity,
        _rel(m.group(3)!),
        int.parse(m.group(4)!),
        m.group(2)!,
      ),
    );
  }
  return out;
}

Future<void> main(List<String> args) async {
  final asJson = args.contains('--json');
  final withAnalyze = args.contains('--analyze');
  final onlyArg = args.firstWhere(
    (a) => a.startsWith('--only='),
    orElse: () => '',
  );
  final only = onlyArg.isEmpty
      ? null
      : onlyArg.substring('--only='.length).split(',').toSet();

  final root = Directory('lib');
  if (!root.existsSync()) {
    stderr.writeln('Run this from the repo root (no lib/ here).');
    exit(2);
  }

  final sources = <String, String>{}; // rel path -> source
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    sources[_rel(entity.path)] = entity.readAsStringSync();
  }

  for (final entry in sources.entries) {
    final source = entry.value;
    final lines = const LineSplitter().convert(source);
    checkArchitecture(entry.key, lines);
    checkPlatform(entry.key, lines, source);
    checkLifecycle(entry.key, lines, source);
    checkRuntime(entry.key, lines);
  }
  reportPlatformImports(buildImporterGraph(sources));

  if (withAnalyze) findings.addAll(await runFlutterAnalyze());

  var result = findings.toList();
  if (only != null) result = result.where((f) => only.contains(f.group)).toList();
  result.sort((a, b) {
    final s = _severityOrder[a.severity]!.compareTo(_severityOrder[b.severity]!);
    if (s != 0) return s;
    final f = a.file.compareTo(b.file);
    return f != 0 ? f : a.line.compareTo(b.line);
  });

  int count(String severity) =>
      result.where((f) => f.severity == severity).length;

  if (asJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'total': result.length,
        'bySeverity': {for (final s in _severityOrder.keys) s: count(s)},
        'findings': result.map((f) => f.toJson()).toList(),
      }),
    );
  } else {
    if (result.isEmpty) stdout.writeln('No findings.');
    for (final f in result) {
      stdout.writeln('[${f.severity}] ${f.rule}');
      stdout.writeln('    ${f.file}:${f.line}');
      stdout.writeln('    ${f.message}');
      if (f.hint != null) stdout.writeln('    -> ${f.hint}');
    }
    stdout.writeln(
      '\n${result.length} findings  '
      '(high ${count('high')}, medium ${count('medium')}, low ${count('low')})',
    );
  }

  exit(count('high') > 0 ? 1 : 0);
}
