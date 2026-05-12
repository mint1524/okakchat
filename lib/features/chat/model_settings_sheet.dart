import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';
import 'chat_provider.dart';

// ── Presets ───────────────────────────────────────────────────────────────

class _Preset {
  const _Preset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.temperature,
    required this.maxTokens,
    this.systemPrompt,
  });
  final String id, name, description;
  final IconData icon;
  final double temperature;
  final int maxTokens;
  final String? systemPrompt;
}

const _presets = [
  _Preset(
    id: 'balanced',
    name: 'Balanced',
    description: 'General use',
    icon: Icons.balance_rounded,
    temperature: 0.7,
    maxTokens: 4096,
  ),
  _Preset(
    id: 'precise',
    name: 'Precise',
    description: 'Facts & analysis',
    icon: Icons.precision_manufacturing_rounded,
    temperature: 0.1,
    maxTokens: 8192,
  ),
  _Preset(
    id: 'creative',
    name: 'Creative',
    description: 'Writing & ideas',
    icon: Icons.auto_awesome_rounded,
    temperature: 1.2,
    maxTokens: 4096,
  ),
  _Preset(
    id: 'coding',
    name: 'Coding',
    description: 'Code generation',
    icon: Icons.code_rounded,
    temperature: 0.05,
    maxTokens: 8192,
    systemPrompt:
        'You are an expert software engineer. Provide clean, production-ready code with brief explanations. Prefer modern idioms and best practices.',
  ),
];

// ── Response length ───────────────────────────────────────────────────────

class _Length {
  const _Length(this.label, this.tokens, this.icon);
  final String label;
  final int tokens;
  final IconData icon;
}

const _lengths = [
  _Length('Concise', 1024, Icons.short_text_rounded),
  _Length('Normal',  4096, Icons.subject_rounded),
  _Length('Detailed',8192, Icons.article_rounded),
  _Length('Extended',16384,Icons.menu_book_rounded),
];

// ── Sheet ─────────────────────────────────────────────────────────────────

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
  bool _showSystemPrompt = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(chatProvider);
    _sysCtrl = TextEditingController(text: s.systemPrompt ?? '');
    _showSystemPrompt =
        s.systemPrompt != null && s.systemPrompt!.isNotEmpty;
  }

  @override
  void dispose() {
    _sysCtrl.dispose();
    super.dispose();
  }

  String _activePresetId(ChatState s) {
    for (final p in _presets) {
      if ((p.temperature - s.temperature).abs() < 0.01 &&
          p.maxTokens == s.maxTokens) return p.id;
    }
    return '';
  }

  void _applyPreset(_Preset p) {
    final n = ref.read(chatProvider.notifier);
    n.setTemperature(p.temperature);
    n.setMaxTokens(p.maxTokens);
    if (p.systemPrompt != null) {
      n.setSystemPrompt(p.systemPrompt);
      _sysCtrl.text = p.systemPrompt!;
      setState(() => _showSystemPrompt = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final activePreset = _activePresetId(state);
    final activeLength = _lengths.firstWhere(
      (l) => l.tokens == state.maxTokens,
      orElse: () => _lengths[1],
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppTheme.blue500.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.textLow,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 17, color: AppTheme.blue400),
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
          Container(height: 1,
              color: AppTheme.blue500.withValues(alpha: 0.1)),

          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                // ── Style presets ─────────────────────────────────────
                _Label('Style'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
                  children: _presets.map((p) {
                    final sel = activePreset == p.id;
                    return GestureDetector(
                      onTap: () => _applyPreset(p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.blue500.withValues(alpha: 0.18)
                              : AppTheme.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppTheme.blue500.withValues(alpha: 0.5)
                                : AppTheme.blue500.withValues(alpha: 0.1),
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(p.icon, size: 22,
                                color: sel ? AppTheme.blue400
                                    : AppTheme.textMid),
                            const SizedBox(height: 6),
                            Text(p.name,
                                style: GoogleFonts.sora(
                                    fontSize: 11,
                                    fontWeight: sel ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: sel ? AppTheme.blue300
                                        : AppTheme.textMid)),
                            Text(p.description,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sora(
                                    fontSize: 9,
                                    color: AppTheme.textLow,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // ── Response length ───────────────────────────────────
                _Label('Response length'),
                const SizedBox(height: 10),
                Row(children: _lengths.map((l) {
                  final sel = activeLength.label == l.label;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => notifier.setMaxTokens(l.tokens),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: EdgeInsets.only(
                            right: l == _lengths.last ? 0 : 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppTheme.blue500.withValues(alpha: 0.15)
                              : AppTheme.surface2,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: sel
                                ? AppTheme.blue500.withValues(alpha: 0.4)
                                : AppTheme.blue500.withValues(alpha: 0.08),
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(children: [
                          Icon(l.icon, size: 15,
                              color: sel ? AppTheme.blue400
                                  : AppTheme.textMid),
                          const SizedBox(height: 4),
                          Text(l.label,
                              style: GoogleFonts.sora(
                                  fontSize: 10,
                                  fontWeight: sel ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: sel ? AppTheme.blue300
                                      : AppTheme.textMid)),
                        ]),
                      ),
                    ),
                  );
                }).toList()),

                const SizedBox(height: 24),

                // ── System prompt (collapsible) ───────────────────────
                GestureDetector(
                  onTap: () =>
                      setState(() => _showSystemPrompt = !_showSystemPrompt),
                  child: Row(children: [
                    Icon(Icons.psychology_outlined,
                        size: 15, color: AppTheme.textMid),
                    const SizedBox(width: 6),
                    Text('System prompt',
                        style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMid)),
                    if (state.systemPrompt != null &&
                        state.systemPrompt!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                            color: AppTheme.blue400, shape: BoxShape.circle),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      _showSystemPrompt
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18, color: AppTheme.textMid),
                  ]),
                ),
                if (_showSystemPrompt) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sysCtrl,
                    maxLines: 5,
                    style: GoogleFonts.sora(
                        fontSize: 13, color: AppTheme.textHigh),
                    cursorColor: AppTheme.blue400,
                    decoration: InputDecoration(
                      hintText: 'You are a helpful assistant…',
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
                ],

                const SizedBox(height: 20),

                // ── Reset ─────────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    notifier.setTemperature(0.7);
                    notifier.setMaxTokens(4096);
                    notifier.setSystemPrompt(null);
                    _sysCtrl.clear();
                    setState(() => _showSystemPrompt = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: AppTheme.blue500.withValues(alpha: 0.1)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.refresh_rounded,
                          size: 14, color: AppTheme.textMid),
                      const SizedBox(width: 6),
                      Text('Reset to defaults',
                          style: GoogleFonts.sora(
                              fontSize: 12, color: AppTheme.textMid)),
                    ]),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.sora(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textMid,
          letterSpacing: 0.5));
}
