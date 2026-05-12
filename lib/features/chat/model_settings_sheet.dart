import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';

class ModelSettingsSheet extends ConsumerStatefulWidget {
  const ModelSettingsSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModelSettingsSheet._(),
    );
  }

  @override
  ConsumerState<ModelSettingsSheet> createState() =>
      _ModelSettingsSheetState();
}

class _ModelSettingsSheetState extends ConsumerState<ModelSettingsSheet> {
  late TextEditingController _sysCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(chatProvider);
    _sysCtrl = TextEditingController(text: s.systemPrompt ?? '');
  }

  @override
  void dispose() {
    _sysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textLow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                Icon(Icons.tune_rounded, size: 18, color: AppTheme.blue400),
                const SizedBox(width: 8),
                Text('Model settings',
                    style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textHigh)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done',
                      style: GoogleFonts.sora(
                          fontSize: 13,
                          color: AppTheme.blue400,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            Divider(height: 1, color: AppTheme.blue500.withValues(alpha: 0.1)),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  // Temperature
                  _SectionLabel('Temperature', '${state.temperature.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.blue500,
                      inactiveTrackColor: AppTheme.surface3,
                      thumbColor: AppTheme.blue400,
                      overlayColor: AppTheme.blue500.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: state.temperature,
                      min: 0.0,
                      max: 2.0,
                      divisions: 40,
                      onChanged: notifier.setTemperature,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Precise (0)', style: _hint),
                      Text('Creative (2)', style: _hint),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Max tokens
                  _SectionLabel('Max tokens', '${state.maxTokens}'),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.blue500,
                      inactiveTrackColor: AppTheme.surface3,
                      thumbColor: AppTheme.blue400,
                      overlayColor: AppTheme.blue500.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: state.maxTokens.toDouble(),
                      min: 256,
                      max: 16384,
                      divisions: 63,
                      onChanged: (v) => notifier.setMaxTokens(v.round()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('256', style: _hint),
                      Text('16 384', style: _hint),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // System prompt
                  Row(children: [
                    Icon(Icons.psychology_outlined,
                        size: 14, color: AppTheme.textMid),
                    const SizedBox(width: 6),
                    Text('System prompt',
                        style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMid)),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sysCtrl,
                    maxLines: 5,
                    style: GoogleFonts.sora(
                        fontSize: 13, color: AppTheme.textHigh),
                    cursorColor: AppTheme.blue400,
                    decoration: InputDecoration(
                      hintText:
                          'You are a helpful assistant…',
                      hintStyle: GoogleFonts.sora(
                          fontSize: 13, color: AppTheme.textLow),
                      filled: true,
                      fillColor: AppTheme.surface2,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppTheme.blue500.withValues(alpha: 0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppTheme.blue500.withValues(alpha: 0.5),
                            width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: notifier.setSystemPrompt,
                  ),

                  const SizedBox(height: 24),

                  // Reset button
                  TextButton.icon(
                    onPressed: () {
                      notifier.setTemperature(0.7);
                      notifier.setMaxTokens(4096);
                      notifier.setSystemPrompt(null);
                      _sysCtrl.clear();
                    },
                    icon: Icon(Icons.refresh_rounded,
                        size: 14, color: AppTheme.textMid),
                    label: Text('Reset to defaults',
                        style: GoogleFonts.sora(
                            fontSize: 12, color: AppTheme.textMid)),
                  ),

                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _hint => GoogleFonts.sora(
      fontSize: 11, color: AppTheme.textLow);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.blue900,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: AppTheme.blue500.withValues(alpha: 0.25)),
          ),
          child: Text(value,
              style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.blue300)),
        ),
      ]);
}
