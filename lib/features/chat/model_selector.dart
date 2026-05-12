import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';

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

    final validId = models.any((m) => m['id'] == selectedModel)
        ? selectedModel
        : models.first['id'] as String;
    final selected = models.firstWhere((m) => m['id'] == validId);

    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: AppTheme.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.blue500.withValues(alpha: 0.2)),
      ),
      itemBuilder: (_) => models.map((m) {
        final id = m['id'] as String;
        final name = m['displayName'] as String;
        final isSelected = id == validId;
        return PopupMenuItem<String>(
          value: id,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(children: [
            if (isSelected)
              Icon(Icons.check_rounded, size: 14, color: AppTheme.blue400)
            else
              const SizedBox(width: 14),
            const SizedBox(width: 8),
            Text(name,
                style: GoogleFonts.sora(
                    fontSize: 13,
                    color: isSelected ? AppTheme.blue300 : AppTheme.textHigh,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ]),
        );
      }).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.blue500.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(
              selected['displayName'] as String,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textHigh),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.expand_more_rounded,
              size: 16, color: AppTheme.textMid),
        ]),
      ),
    );
  }
}
