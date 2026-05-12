import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:okakchat/core/theme/platform_utils.dart';
import 'package:okakchat/features/chat/chat_screen.dart';
import 'package:okakchat/features/chat/chat_provider.dart';
import 'tool_definitions.dart';
import 'tools/tool_executor.dart';

class AgentScreen extends ConsumerStatefulWidget {
  const AgentScreen({super.key});

  @override
  ConsumerState<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends ConsumerState<AgentScreen> {
  String? _workspacePath;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    // Listen for tool calls from the chat provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).toolCallStream.listen(_handleToolCall);
    });
  }

  Future<void> _handleToolCall(Map<String, dynamic> toolCall) async {
    if (_workspacePath == null) return;
    final function = toolCall['function'] as Map<String, dynamic>?;
    if (function == null) return;

    final toolName = function['name'] as String;
    final args = jsonDecode(function['arguments'] as String) as Map<String, dynamic>;

    // Tools that need confirmation
    const confirmTools = {'write_file', 'edit_file', 'execute_command'};
    if (confirmTools.contains(toolName)) {
      final confirmed = await _showConfirmDialog(toolName, args);
      if (!confirmed) {
        ref.read(chatProvider.notifier).addToolResult(toolName, 'User skipped this action.');
        return;
      }
    }

    setState(() => _processing = true);
    final executor = DesktopToolExecutor();
    final result = await executor.dispatch(toolName, args);
    ref.read(chatProvider.notifier).addToolResult(toolName, result);
    setState(() => _processing = false);
  }

  Future<bool> _showConfirmDialog(
      String toolName, Map<String, dynamic> args) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Confirm: $toolName'),
            content: SingleChildScrollView(
              child: Text(
                args.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(toolName == 'execute_command' ? 'Run' : 'Apply'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.supportsAgentMode) {
      return const Scaffold(
        body: Center(
          child: Text('Agent mode is only available on desktop.'),
        ),
      );
    }

    if (_workspacePath == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open, size: 64,
                  color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('Open a workspace folder to start agent mode',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Open folder'),
                onPressed: () async {
                  final result =
                      await FilePicker.platform.getDirectoryPath();
                  if (result != null) {
                    setState(() => _workspacePath = result);
                    ref.read(chatProvider.notifier).setMode('agent');
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Row(children: [
      SizedBox(
        width: 220,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: Text(
                  _workspacePath!.split('/').last,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open, size: 16),
                onPressed: () async {
                  final result =
                      await FilePicker.platform.getDirectoryPath();
                  if (result != null) {
                    setState(() => _workspacePath = result);
                  }
                },
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: _FileTree(root: _workspacePath!)),
        ]),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        child: Stack(children: [
          ChatScreen(
            agentMode: true,
            workspacePath: _workspacePath,
          ),
          if (_processing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ]),
      ),
    ]);
  }
}

class _FileTree extends StatefulWidget {
  const _FileTree({required this.root});
  final String root;

  @override
  State<_FileTree> createState() => _FileTreeState();
}

class _FileTreeState extends State<_FileTree> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FileSystemEntity>>(
      future: Directory(widget.root).list().toList(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data!
          ..sort((a, b) {
            final aIsDir = a is Directory;
            final bIsDir = b is Directory;
            if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
            return a.path.compareTo(b.path);
          });
        return ListView(
          children: entries.map((e) {
            final name = e.path.split('/').last;
            if (name.startsWith('.')) return const SizedBox.shrink();
            return ListTile(
              dense: true,
              leading: Icon(
                e is Directory ? Icons.folder : Icons.insert_drive_file,
                size: 16,
                color: e is Directory
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        );
      },
    );
  }
}
