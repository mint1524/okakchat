import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:okakchat/core/debug/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:okakchat/core/theme/platform_utils.dart';

abstract class ToolExecutor {
  Future<String> readFile(String path);
  Future<String> listDirectory(String path);
  Future<String> searchFiles(String path, String pattern, {String? glob});
  Future<String> writeFile(String path, String content);
  Future<String> editFile(String path, List<Map<String, dynamic>> edits);
  Future<String> executeCommand(String command, {String? workingDir});

  static ToolExecutor get instance {
    if (PlatformUtils.isDesktop) return DesktopToolExecutor();
    throw UnsupportedError('Agent mode not supported on this platform');
  }

  Future<String> dispatch(String toolName, Map<String, dynamic> args) async {
    if (kDebugMode) {
      final argsShort = args.map((k, v) =>
          MapEntry(k, AppLogger.trunc(v.toString(), 60)));
      AppLogger.tool('→ $toolName  $argsShort');
    }
    final result = await _dispatch(toolName, args);
    AppLogger.tool('← $toolName  "${AppLogger.trunc(result, 100)}"');
    return result;
  }

  Future<String> _dispatch(String toolName, Map<String, dynamic> args) async {
    return switch (toolName) {
      'read_file' => readFile(args['path'] as String),
      'list_directory' => listDirectory(args['path'] as String),
      'search_files' => searchFiles(
          args['path'] as String,
          args['pattern'] as String,
          glob: args['glob'] as String?,
        ),
      'write_file' =>
        writeFile(args['path'] as String, args['content'] as String),
      'edit_file' => editFile(
          args['path'] as String,
          (args['edits'] as List).cast<Map<String, dynamic>>(),
        ),
      'execute_command' => executeCommand(
          args['command'] as String,
          workingDir: args['workingDir'] as String?,
        ),
      _ => Future.value('Error: unknown tool $toolName'),
    };
  }
}

class DesktopToolExecutor extends ToolExecutor {
  @override
  Future<String> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return 'Error: file not found: $path';
    return file.readAsString();
  }

  @override
  Future<String> listDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 'Error: directory not found: $path';
    try {
      final entries = await dir
          .list()
          .take(500)
          .toList()
          .timeout(const Duration(seconds: 10));
      entries.sort((a, b) => a.path.compareTo(b.path));
      final lines = entries.map((e) {
        final name = p.basename(e.path);
        return e is Directory ? '$name/' : name;
      }).toList();
      final suffix =
          entries.length == 500 ? '\n… (truncated at 500 entries)' : '';
      return lines.join('\n') + suffix;
    } on TimeoutException {
      return 'Error: listing $path timed out (too large or permission denied)';
    } catch (e) {
      return 'Error listing $path: $e';
    }
  }

  @override
  Future<String> searchFiles(String path, String pattern,
      {String? glob}) async {
    final results = <String>[];
    final regex = RegExp(pattern, multiLine: true);
    final dir = Directory(path);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        if (glob != null &&
            !_matchGlob(p.relative(entity.path, from: path), glob)) {
          continue;
        }
        final content =
            await entity.readAsString().catchError((_) => '');
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (regex.hasMatch(lines[i])) {
            results.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    if (results.isEmpty) return 'No matches found';
    return results.take(100).join('\n');
  }

  @override
  Future<String> writeFile(String path, String content) async {
    await File(path).parent.create(recursive: true);
    await File(path).writeAsString(content);
    return 'Written: $path';
  }

  @override
  Future<String> editFile(
      String path, List<Map<String, dynamic>> edits) async {
    final file = File(path);
    if (!await file.exists()) return 'Error: file not found: $path';
    var content = await file.readAsString();
    for (final edit in edits) {
      final old = edit['oldText'] as String;
      final replacement = edit['newText'] as String;
      if (!content.contains(old)) {
        return 'Error: oldText not found in $path';
      }
      content = content.replaceFirst(old, replacement);
    }
    await file.writeAsString(content);
    return 'Edited: $path';
  }

  @override
  Future<String> executeCommand(String command,
      {String? workingDir}) async {
    // cmd.exe on Windows; /bin/sh everywhere else.
    final shell = Platform.isWindows ? 'cmd.exe' : '/bin/sh';
    final args = Platform.isWindows ? ['/c', command] : ['-c', command];
    try {
      final result = await Process.run(
        shell,
        args,
        workingDirectory: workingDir,
      ).timeout(const Duration(minutes: 2));
      final out = result.stdout.toString();
      final err = result.stderr.toString();
      return [if (out.isNotEmpty) out, if (err.isNotEmpty) err].join('\n');
    } on TimeoutException {
      return 'Error: command timed out after 2 minutes';
    } catch (e) {
      return 'Error executing command: $e';
    }
  }

  bool _matchGlob(String path, String glob) {
    final pattern = glob
        .replaceAll('.', '\\.')
        .replaceAll('**/', '(.+/)?')
        .replaceAll('*', '[^/]*');
    return RegExp('^$pattern\$').hasMatch(path);
  }

}
