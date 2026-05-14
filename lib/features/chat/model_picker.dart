import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:okakchat/core/theme/app_theme.dart';

// ── Provider ──────────────────────────────────────────────────────────────

enum _Provider { anthropic, openai, google, other }

String _providerLabel(_Provider p) {
  switch (p) {
    case _Provider.anthropic: return 'Anthropic';
    case _Provider.openai:    return 'OpenAI';
    case _Provider.google:    return 'Google';
    case _Provider.other:     return 'Other';
  }
}

Color _providerColor(_Provider p) {
  switch (p) {
    case _Provider.anthropic: return const Color(0xFFE8834E);
    case _Provider.openai:    return const Color(0xFF34D399);
    case _Provider.google:    return const Color(0xFF60A5FA);
    case _Provider.other:     return const Color(0xFFA78BFA);
  }
}

_Provider _providerOf(String modelId) {
  final id = modelId.toLowerCase();
  if (id.startsWith('claude')) return _Provider.anthropic;
  if (id.startsWith('gpt') ||
      id.startsWith('o1') ||
      id.startsWith('o3') ||
      id.startsWith('codex')) {
    return _Provider.openai;
  }
  if (id.startsWith('gemini')) return _Provider.google;
  return _Provider.other;
}

// ── Level extraction from display name ───────────────────────────────────

const _kLevelSuffixes = [
  'High Thinking',
  'Medium Thinking',
  'Low',
  'Medium',
  'High',
  'None',
  'Thinking',
];

String _extractBase(String displayName) {
  for (final s in _kLevelSuffixes) {
    if (displayName.endsWith(' $s')) {
      return displayName.substring(0, displayName.length - s.length - 1);
    }
  }
  return displayName;
}

String _extractLevel(String displayName) {
  for (final s in _kLevelSuffixes) {
    if (displayName.endsWith(' $s')) return s;
  }
  return 'Auto';
}

// ── Data model ────────────────────────────────────────────────────────────

class _Variant {
  const _Variant(this.modelId, this.label);
  final String modelId;
  final String label;
}

class _Group {
  const _Group(this.baseName, this.variants, this.provider);
  final String baseName;
  final List<_Variant> variants;
  final _Provider provider;
}

Map<_Provider, List<_Group>> _buildGroups(List<Map<String, dynamic>> models) {
  final order = <String>[];
  final variantMap = <String, List<_Variant>>{};
  final providerMap = <String, _Provider>{};

  for (final m in models) {
    final id = m['id'] as String;
    final name = m['displayName'] as String;
    final base = _extractBase(name);
    if (!variantMap.containsKey(base)) {
      order.add(base);
      variantMap[base] = [];
      providerMap[base] = _providerOf(id);
    }
    variantMap[base]!.add(_Variant(id, _extractLevel(name)));
  }

  final result = <_Provider, List<_Group>>{};
  for (final base in order) {
    final provider = providerMap[base]!;
    (result[provider] ??= [])
        .add(_Group(base, List.unmodifiable(variantMap[base]!), provider));
  }
  return result;
}

// ── Public widget ─────────────────────────────────────────────────────────

class ModelPickerButton extends StatefulWidget {
  const ModelPickerButton({
    super.key,
    required this.selectedModel,
    required this.models,
    required this.onSelected,
  });

  final String selectedModel;
  final List<Map<String, dynamic>> models;
  final void Function(String) onSelected;

  @override
  State<ModelPickerButton> createState() => _ModelPickerButtonState();
}

class _ModelPickerButtonState extends State<ModelPickerButton> {
  final _portalCtrl = OverlayPortalController();
  final _link = LayerLink();

  String get _displayName {
    final m = widget.models
        .where((m) => m['id'] == widget.selectedModel)
        .firstOrNull;
    return m?['displayName'] as String? ?? widget.selectedModel;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.models.isEmpty) return const SizedBox.shrink();

    return CompositedTransformTarget(
      link: _link,
      child: TapRegion(
        groupId: _link,
        onTapOutside: (_) => _portalCtrl.hide(),
        child: OverlayPortal(
          controller: _portalCtrl,
          overlayChildBuilder: (ctx) => CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -8),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: TapRegion(
                groupId: _link,
                child: _ModelPickerPanel(
                  models: widget.models,
                  selectedModelId: widget.selectedModel,
                  onSelected: widget.onSelected,
                  onClose: _portalCtrl.hide,
                ),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () => _portalCtrl.isShowing
                ? _portalCtrl.hide()
                : _portalCtrl.show(),
            child: _Trigger(name: _displayName),
          ),
        ),
      ),
    );
  }
}

// ── Trigger button ────────────────────────────────────────────────────────

class _Trigger extends StatelessWidget {
  const _Trigger({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: AppTheme.blue500.withValues(alpha: 0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.psychology_rounded,
              size: 13, color: AppTheme.blue400),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                  fontSize: 12,
                  color: AppTheme.textHigh,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded,
              size: 13, color: AppTheme.textMid),
        ]),
      );
}

// ── Picker panel ──────────────────────────────────────────────────────────

class _ModelPickerPanel extends StatefulWidget {
  const _ModelPickerPanel({
    required this.models,
    required this.selectedModelId,
    required this.onSelected,
    required this.onClose,
  });

  final List<Map<String, dynamic>> models;
  final String selectedModelId;
  final void Function(String) onSelected;
  final VoidCallback onClose;

  @override
  State<_ModelPickerPanel> createState() => _ModelPickerPanelState();
}

class _ModelPickerPanelState extends State<_ModelPickerPanel> {
  late Map<_Provider, List<_Group>> _groups;
  late List<_Provider> _providers;
  late _Provider _tab;
  String? _pendingBase;

  @override
  void initState() {
    super.initState();
    _groups = _buildGroups(widget.models);
    _providers = _groups.keys.toList();
    _tab = _providerOf(widget.selectedModelId);
    if (!_providers.contains(_tab) && _providers.isNotEmpty) {
      _tab = _providers.first;
    }
  }

  @override
  void didUpdateWidget(_ModelPickerPanel old) {
    super.didUpdateWidget(old);
    if (widget.selectedModelId != old.selectedModelId &&
        _pendingBase != null) {
      final group = _groupForBase(_pendingBase);
      final inPending =
          group?.variants.any((v) => v.modelId == widget.selectedModelId) ??
              false;
      if (!inPending) setState(() => _pendingBase = null);
    }
  }

  String? get _activeBase {
    if (_pendingBase != null) return _pendingBase;
    for (final groups in _groups.values) {
      for (final g in groups) {
        for (final v in g.variants) {
          if (v.modelId == widget.selectedModelId) return g.baseName;
        }
      }
    }
    return null;
  }

  _Group? _groupForBase(String? baseName) {
    if (baseName == null) return null;
    for (final groups in _groups.values) {
      for (final g in groups) {
        if (g.baseName == baseName) return g;
      }
    }
    return null;
  }

  void _onGroupTap(_Group g) {
    if (g.variants.length == 1) {
      widget.onSelected(g.variants.first.modelId);
      widget.onClose();
      return;
    }
    setState(() => _pendingBase = g.baseName);
    final alreadyInGroup =
        g.variants.any((v) => v.modelId == widget.selectedModelId);
    if (!alreadyInGroup) {
      widget.onSelected(g.variants.first.modelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBase = _activeBase;
    final thinkingGroup = _groupForBase(activeBase);
    final showThinking =
        thinkingGroup != null && thinkingGroup.variants.length > 1;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 480),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.blue500.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProviderTabBar(
              providers: _providers,
              active: _tab,
              onTap: (p) => setState(() => _tab = p),
            ),
            Container(
                height: 1,
                color: AppTheme.blue500.withValues(alpha: 0.1)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: (_groups[_tab] ?? []).map((g) {
                  final isSelected = g.variants.any(
                      (v) => v.modelId == widget.selectedModelId);
                  final isPending = g.baseName == _pendingBase &&
                      _pendingBase != null &&
                      !isSelected;
                  return _GroupRow(
                    group: g,
                    isSelected: isSelected,
                    isPending: isPending,
                    selectedModelId: widget.selectedModelId,
                    onTap: () => _onGroupTap(g),
                  );
                }).toList(),
              ),
            ),
            if (showThinking) ...[
              Container(
                  height: 1,
                  color: AppTheme.blue500.withValues(alpha: 0.1)),
              _ThinkingBar(
                variants: thinkingGroup.variants,
                selectedId: widget.selectedModelId,
                onSelect: (id) {
                  widget.onSelected(id);
                  widget.onClose();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Provider tab bar ──────────────────────────────────────────────────────

class _ProviderTabBar extends StatelessWidget {
  const _ProviderTabBar({
    required this.providers,
    required this.active,
    required this.onTap,
  });

  final List<_Provider> providers;
  final _Provider active;
  final void Function(_Provider) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: providers.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          final isActive = p == active;
          final color = _providerColor(p);
          final isFirst = i == 0;
          final isLast = i == providers.length - 1;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.only(
                    topLeft: isFirst
                        ? const Radius.circular(11)
                        : Radius.zero,
                    topRight: isLast
                        ? const Radius.circular(11)
                        : Radius.zero,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    _providerLabel(p),
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isActive ? color : AppTheme.textMid,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Model group row ───────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.isSelected,
    required this.isPending,
    required this.selectedModelId,
    required this.onTap,
  });

  final _Group group;
  final bool isSelected;
  final bool isPending;
  final String selectedModelId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String? levelHint;
    if (isSelected && group.variants.length > 1) {
      final v = group.variants
          .where((v) => v.modelId == selectedModelId)
          .firstOrNull;
      if (v != null && v.label != 'Auto') levelHint = v.label;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: isPending
            ? AppTheme.blue500.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          if (isSelected)
            Icon(Icons.check_rounded,
                size: 14, color: AppTheme.blue400)
          else
            const SizedBox(width: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.baseName,
              style: GoogleFonts.sora(
                fontSize: 13,
                color: isSelected
                    ? AppTheme.blue300
                    : AppTheme.textHigh,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (levelHint != null) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                levelHint,
                style: GoogleFonts.sora(
                    fontSize: 10,
                    color: AppTheme.blue400,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
          if (group.variants.length > 1) ...[
            const SizedBox(width: 4),
            Icon(Icons.tune_rounded,
                size: 11, color: AppTheme.textLow),
          ],
        ]),
      ),
    );
  }
}

// ── Thinking level bar ────────────────────────────────────────────────────

class _ThinkingBar extends StatelessWidget {
  const _ThinkingBar({
    required this.variants,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_Variant> variants;
  final String selectedId;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'THINKING',
              style: GoogleFonts.sora(
                fontSize: 9,
                color: AppTheme.textLow,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: variants.map((v) {
                final isSel = v.modelId == selectedId;
                return GestureDetector(
                  onTap: () => onSelect(v.modelId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppTheme.blue500.withValues(alpha: 0.22)
                          : AppTheme.surface1,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSel
                            ? AppTheme.blue400.withValues(alpha: 0.55)
                            : AppTheme.blue500.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      v.label,
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        color: isSel
                            ? AppTheme.blue300
                            : AppTheme.textMid,
                        fontWeight: isSel
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}
