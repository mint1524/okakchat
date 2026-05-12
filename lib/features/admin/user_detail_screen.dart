import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:okakchat/core/auth/auth_provider.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  const UserDetailScreen(
      {super.key, required this.userId, required this.email});
  final String userId, email;

  @override
  ConsumerState<UserDetailScreen> createState() =>
      _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  final _noteCtrl = TextEditingController();
  String _plan = 'pro';
  DateTime? _expires;
  bool _loading = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _grantSub() async {
    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post(
        '/api/admin/users/${widget.userId}/subscription',
        data: {
          'planId': _plan,
          if (_expires != null) 'expiresAt': _expires!.toUtc().toIso8601String(),
          if (_noteCtrl.text.isNotEmpty) 'note': _noteCtrl.text,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.email)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Grant subscription',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _plan,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: ['free', 'pro', 'custom']
                    .map((p) => DropdownMenuItem(
                        value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _plan = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_expires == null
                    ? 'Expires: never'
                    : 'Expires: ${_expires!.toLocal().toString().split(' ').first}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 3650)),
                  );
                  if (d != null) setState(() => _expires = d);
                },
              ),
              TextField(
                controller: _noteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _grantSub,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Grant subscription'),
              ),
            ],
          ),
        ),
      );
}
