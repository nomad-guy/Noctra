import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mechanical architecture enforcement for Noctra's lib/ tree.
///
/// Rules (match the audit that established them):
///  1. No source file under lib/ exceeds 300 LOC.
///  2. No import cycles exist between lib/ Dart files.
///  3. Layer direction: `core` imports nothing internal; `data` never imports
///     `services`/`ui`/`providers`; `services` never imports `ui`/`providers`;
///     `ui` never imports `data/sources` directly.
///
/// Relative imports only: package: imports cannot form intra-lib cycles.
void main() {
  final libRoot = Directory('lib');

  Map<String, List<String>> buildImportGraph() {
    final edges = <String, List<String>>{};
    final files = libRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final path = normalize(f.path);
      final deps = <String>[];
      for (final line in f.readAsLinesSync()) {
        final m = RegExp(r"^\s*import '((?:\.\./)+[^']+)'").firstMatch(line);
        if (m == null) continue;
        final targetRaw = m.group(1)!;
        final ups = '../'.allMatches(targetRaw).length;
        var base = path.substring(0, path.lastIndexOf('/'));
        for (var i = 0; i < ups; i++) {
          base = base.substring(0, base.lastIndexOf('/'));
        }
        final rel = targetRaw.substring(ups * 3);
        final resolved = normalize('$base/$rel');
        if (resolved != path) deps.add(resolved);
      }
      edges[path] = deps;
    }
    return edges;
  }

  test('no lib source file exceeds 300 LOC', () {
    final over = <String>[];
    for (final f in libRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final count = f.readAsLinesSync().length;
      if (count > 300) over.add('${f.path} ($count)');
    }
    expect(over, isEmpty, reason: 'Files over 300 LOC:\n${over.join('\n')}');
  });

  test('no import cycles in lib/', () {
    final edges = buildImportGraph();
    final state = <String, int>{};
    final cycles = <List<String>>[];
    final path = <String>[];

    void dfs(String n) {
      state[n] = 1;
      path.add(n);
      for (final d in edges[n] ?? const <String>[]) {
        if (!edges.containsKey(d)) continue;
        if (state[d] == 1) {
          cycles.add(path.sublist(path.indexOf(d))..add(d));
        } else if (state[d] == null) {
          dfs(d);
        }
      }
      path.removeLast();
      state[n] = 2;
    }

    for (final n in edges.keys) {
      if (state[n] == null) dfs(n);
    }
    expect(cycles, isEmpty,
        reason: 'Import cycles:\n${cycles.join('\n')}');
  });

  test('platform code stays inside its boundary', () {
    // Portability rules (cross-platform port). Files under core/, data/models
    // and ui/ must not import dart:io, dart:ffi or construct platform
    // channels; services/ owns platform adapters (audio, resolver, updater,
    // icons). Presentation reaches platform features only through
    // core/platform contracts or service-layer adapters.
    final violations = <String>[];
    final files = libRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final p = normalize(f.path);
      final protected = p.startsWith('lib/core/') ||
          p.startsWith('lib/data/models/') ||
          p.startsWith('lib/ui/');
      if (!protected) continue;
      // core/platform holds the capability contracts and is exempt.
      if (p.startsWith('lib/core/platform/')) continue;
      for (final line in f.readAsLinesSync()) {
        // dart:io / dart:ffi imports leak platform filesystem/native access.
        final m = RegExp(r"^\s*import 'dart:(io|ffi)'").firstMatch(line);
        if (m != null) {
          violations.add('$p -> ${m.group(0)}');
        }
        // Channel construction and raw Platform.is* bypass the capability
        // registry. (flutter/services itself is fine: SystemChrome and
        // HapticFeedback are cross-platform.)
        final ch = RegExp(r"(MethodChannel|EventChannel)\(|Platform\.is")
            .firstMatch(line);
        if (ch != null) {
          violations.add('$p -> ${ch.group(0)}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'Platform boundary violations:\n${violations.join('\n')}');
  });

  test('layer direction rules hold', () {
    final violations = <String>[];
    final files = libRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final p = normalize(f.path);
      for (final line in f.readAsLinesSync()) {
        final m =
            RegExp(r"^\s*import '((?:\.\./)+[^']+)'").firstMatch(line);
        if (m == null) continue;
        final targetRaw = m.group(1)!;
        final ups = '../'.allMatches(targetRaw).length;
        var base = p.substring(0, p.lastIndexOf('/'));
        for (var i = 0; i < ups; i++) {
          base = base.substring(0, base.lastIndexOf('/'));
        }
        final resolved = normalize('$base/${targetRaw.substring(ups * 3)}');

        String? layerOf(String path) {
          if (path.startsWith('lib/core/')) return 'core';
          if (path.startsWith('lib/data/')) return 'data';
          if (path.startsWith('lib/services/')) return 'services';
          if (path.startsWith('lib/providers/')) return 'providers';
          if (path.startsWith('lib/ui/')) return 'ui';
          if (path.startsWith('lib/shared/')) return 'shared';
          return null;
        }

        final src = layerOf(p);
        final dst = layerOf(resolved);
        if (src == null || dst == null) continue;
        // One documented seam: repository parts orchestrate the ytdlp
        // MusicService (a remote provider/data source) for AI curation and
        // download reconciliation. Every other data -> services import is
        // forbidden; the allowlist is exact so new edges still fail.
        final allowedDataToService = src == 'data' &&
            dst == 'services' &&
            resolved == 'lib/services/ytdlp/music_service.dart' &&
            p.startsWith('lib/data/repositories/');
        final bad = (src == 'core' && dst != 'core') ||
            (src == 'data' &&
                dst == 'services' &&
                !allowedDataToService) ||
            (src == 'data' && (dst == 'ui' || dst == 'providers')) ||
            (src == 'services' && (dst == 'ui' || dst == 'providers')) ||
            (src == 'ui' && dst == 'data' &&
                resolved.startsWith('lib/data/sources/'));
        if (bad) {
          violations.add('$p -> $resolved');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'Layer violations:\n${violations.join('\n')}');
  });
}

String normalize(String p) {
  return p.replaceAll('\\', '/');
}
