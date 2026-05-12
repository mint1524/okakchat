import 'package:flutter/material.dart';

class ModelSelector extends StatelessWidget {
  const ModelSelector({
    super.key,
    required this.selectedModel,
    required this.models,
    required this.onSelected,
  });
  final String selectedModel;
  final List<Map<String, dynamic>> models;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox.shrink();
    final validValue = models.any((m) => m['id'] == selectedModel)
        ? selectedModel
        : models.first['id'] as String;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: validValue,
        items: models
            .map((m) => DropdownMenuItem(
                  value: m['id'] as String,
                  child: Text(m['displayName'] as String),
                ))
            .toList(),
        onChanged: (v) => v != null ? onSelected(v) : null,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
