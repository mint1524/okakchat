import 'dart:io';
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

class DesktopToolExecutor implements ToolExecutor {
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
    final entries = await dir.list().toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    return entries.map((e) {
      final name = p.basename(e.path);
      return e is Directory ? '$name/' : name;
    }).join('\n');
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
    final result = await Process.run(
      '/bin/sh',
      ['-c', command],
      workingDirectory: workingDir,
    );
    final out = result.stdout.toString();
    final err = result.stderr.toString();
    return [if (out.isNotEmpty) out, if (err.isNotEmpty) err].join('\n');
  }

  bool _matchGlob(String path, String glob) {
    final pattern = glob
        .replaceAll('.', '\\.')
        .replaceAll('**/', '(.+/)?')
        .replaceAll('*', '[^/]*');
    return RegExp('^$pattern\$').hasMatch(path);
  }

  @override
  Future<String> dispatch(String toolName, Map<String, dynamic> args) =>
      ToolExecutor.instance.dispatch(toolName, args);
}
