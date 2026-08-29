import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/skills_data.dart';
import '../../l10n/l10n.dart';
import '../../models/skill.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/skills_provider.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Zoomable, pannable skill grid that fills the 50% control panel.
class SkillTreeTab extends ConsumerWidget {
  const SkillTreeTab({super.key});

  static const double _cellW = 96;
  static const double _cellH = 108;
  static const double _nodeSize = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(playerProvider.select((p) => p.skillPoints));
    final gold = ref.watch(playerProvider.select((p) => p.gold));
    final spent = ref.watch(skillPointsSpentProvider);
    final l10n = ref.watch(l10nProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderColor: available > 0
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.outline,
            child: Row(
              children: [
                Icon(
                  Icons.account_tree,
                  size: 18,
                  color: available > 0 ? AppColors.gold : AppColors.textFaint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t(
                          available == 1
                              ? 'ui.skillPointsOne'
                              : 'ui.skillPoints',
                          {'n': '$available'},
                        ),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: available > 0
                              ? AppColors.gold
                              : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        l10n.t('ui.skillTreeHint', {
                          'spent': '$spent',
                          'gold': '$gold',
                        }),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 26,
                  child: OutlinedButton(
                    onPressed: spent == 0
                        ? null
                        : () => ref.read(skillsProvider.notifier).respec(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Text(l10n.t('ui.respec')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: _Legend(),
        ),
        Expanded(
          child: ClipRect(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(72),
              minScale: 0.55,
              maxScale: 2.4,
              child: SizedBox(
                width: skillTreeColumns * _cellW,
                height: skillTreeRows * _cellH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConnectorPainter(
                          cellW: _cellW,
                          cellH: _cellH,
                          nodeSize: _nodeSize,
                          ranks: ref.watch(skillsProvider),
                        ),
                      ),
                    ),
                    for (final skill in allSkills)
                      Positioned(
                        left: skill.col * _cellW + (_cellW - _nodeSize) / 2,
                        top: skill.row * _cellH + 6,
                        child: _SkillNode(skill: skill, size: _nodeSize),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends ConsumerWidget {
  const _Legend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return Row(
      children: [
        for (final branch in SkillBranch.values)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(branch.icon, size: 12, color: branch.color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    l10n.branch(branch),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: branch.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Draws a link from every node to each of its prerequisites.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.cellW,
    required this.cellH,
    required this.nodeSize,
    required this.ranks,
  });

  final double cellW;
  final double cellH;
  final double nodeSize;
  final Map<String, int> ranks;

  @override
  void paint(Canvas canvas, Size size) {
    Offset centerOf(SkillDef skill) => Offset(
      skill.col * cellW + cellW / 2,
      skill.row * cellH + 6 + nodeSize / 2,
    );

    for (final skill in allSkills) {
      for (final prereqId in skill.requires) {
        final prereq = skillCatalog[prereqId];
        if (prereq == null) continue;
        final lit = (ranks[prereq.id] ?? 0) > 0;
        canvas.drawLine(
          centerOf(prereq),
          centerOf(skill),
          Paint()
            ..color = lit
                ? skill.branch.color.withValues(alpha: 0.7)
                : AppColors.outline
            ..strokeWidth = lit ? 3 : 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.ranks != ranks || old.cellW != cellW || old.cellH != cellH;
}

class _SkillNode extends ConsumerWidget {
  const _SkillNode({required this.skill, required this.size});

  final SkillDef skill;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(skillsProvider)[skill.id] ?? 0;
    ref.watch(playerProvider);
    final block = ref.read(skillsProvider.notifier).blockFor(skill);
    final learned = rank > 0;
    final maxed = rank >= skill.maxRank;
    final canLearn = block == null;
    final color = skill.branch.color;
    final l10n = ref.watch(l10nProvider);

    return SizedBox(
      width: size,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(_radiusFor(skill.kind, size)),
              onTap: () => _showDetails(context),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    _radiusFor(skill.kind, size),
                  ),
                  color: learned
                      ? color.withValues(alpha: 0.22)
                      : AppColors.surface,
                  border: Border.all(
                    color: maxed
                        ? AppColors.gold
                        : (learned
                              ? color
                              : (canLearn
                                    ? color.withValues(alpha: 0.65)
                                    : AppColors.outline)),
                    width: maxed || canLearn ? 2 : 1.2,
                  ),
                  boxShadow: canLearn && !maxed
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      skill.icon,
                      size: size * 0.40,
                      color: learned
                          ? color
                          : (canLearn ? color : AppColors.textFaint),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: _KindDot(kind: skill.kind),
                    ),
                    Positioned(
                      bottom: 3,
                      child: Text(
                        '$rank/${skill.maxRank}',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: maxed
                              ? AppColors.gold
                              : (learned ? color : AppColors.textFaint),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            l10n.skillName(skill.id),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.6,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: learned ? AppColors.text : AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  static double _radiusFor(SkillNodeKind kind, double size) => switch (kind) {
    SkillNodeKind.booster => size / 2,
    SkillNodeKind.perk => 10,
    SkillNodeKind.active => 8,
  };

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _SkillSheet(skill: skill),
    );
  }
}

class _KindDot extends StatelessWidget {
  const _KindDot({required this.kind});

  final SkillNodeKind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      SkillNodeKind.booster => AppColors.gold,
      SkillNodeKind.perk => AppColors.success,
      SkillNodeKind.active => AppColors.mana,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: kind == SkillNodeKind.booster
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: kind == SkillNodeKind.booster
            ? null
            : BorderRadius.circular(1.5),
      ),
    );
  }
}

class _SkillSheet extends ConsumerWidget {
  const _SkillSheet({required this.skill});

  final SkillDef skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(skillsProvider)[skill.id] ?? 0;
    ref.watch(playerProvider);
    final notifier = ref.read(skillsProvider.notifier);
    final block = notifier.blockFor(skill);
    final gold = notifier.goldFor(skill);
    final color = skill.branch.color;
    final l10n = ref.watch(l10nProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      skill.kind == SkillNodeKind.booster ? 22 : 10,
                    ),
                    color: color.withValues(alpha: 0.18),
                    border: Border.all(color: color),
                  ),
                  child: Icon(skill.icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.skillName(skill.id),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        '${l10n.branch(skill.branch)} · '
                        '${l10n.skillKind(skill.kind)} · '
                        '${l10n.t('ui.rank', {'n': '$rank', 'max': '${skill.maxRank}'})}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.skillDesc(skill.id),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ..._effectLines(rank, l10n),
            const SizedBox(height: 10),
            Row(
              children: [
                ResourceChip(
                  icon: Icons.monetization_on,
                  value: gold == 0 ? l10n.t('ui.free') : formatCount(gold),
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                ResourceChip(
                  icon: Icons.auto_awesome,
                  value: l10n.t('ui.skillPointCost', {
                    'n': '${skill.skillPointCost}',
                  }),
                  color: AppColors.xp,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: block == null
                    ? () {
                        ref.read(skillsProvider.notifier).learn(skill.id);
                        Navigator.of(context).pop();
                      }
                    : null,
                child: Text(
                  block == null
                      ? (rank == 0 ? l10n.t('ui.unlock') : l10n.t('ui.rankUp'))
                      : block.label(skill, l10n, gold: gold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _effectLines(int rank, L10n l10n) {
    final lines = <Widget>[];

    void addTitle(String title) {
      lines.add(SectionTitle(title));
    }

    void addLine(String text, Color color) {
      lines.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      );
    }

    switch (skill.kind) {
      case SkillNodeKind.booster:
        addTitle(l10n.t('ui.perRank'));
        for (final line in l10n.describeBundle(skill.perRank)) {
          addLine(line, AppColors.success);
        }
        if (rank > 0) {
          addTitle(l10n.t('ui.currentTotal'));
          for (final line in l10n.describeBundle(skill.bonusAt(rank))) {
            addLine(line, skill.branch.color);
          }
        }
      case SkillNodeKind.perk:
        addTitle(l10n.t('ui.perk'));
        addLine(
          _perkLine(l10n, skill.perk!, skill.perkPerRank),
          AppColors.success,
        );
        if (rank > 0) {
          addLine(
            l10n.t('ui.perkNow', {
              'line': _perkLine(l10n, skill.perk!, skill.perkPerRank * rank),
            }),
            skill.branch.color,
          );
        }
      case SkillNodeKind.active:
        addTitle(l10n.t('ui.autoCast'));
        addLine(
          l10n.t('ui.activeStats', {
            'power': '${skill.activePower}',
            'mana': '${skill.manaCost.round()}',
            'cd': skill.cooldown.toStringAsFixed(0),
          }),
          AppColors.mana,
        );
        if (rank > 0) {
          addLine(
            l10n.t('ui.activeRankPower', {
              'rank': '$rank',
              'power': (skill.activePower * rank).toStringAsFixed(1),
            }),
            skill.branch.color,
          );
        }
    }
    return lines;
  }

  static String _perkLine(L10n l10n, PerkEffect perk, double amount) =>
      switch (perk) {
        PerkEffect.doubleLoot => l10n.t('perk.doubleLoot', {
          'n': (amount * 100).toStringAsFixed(0),
        }),
        PerkEffect.execute => l10n.t('perk.execute', {
          'n': (amount * 100).toStringAsFixed(0),
        }),
        PerkEffect.thorns => l10n.t('perk.thorns', {
          'n': (amount * 100).toStringAsFixed(0),
        }),
        PerkEffect.goldOnHit => l10n.t('perk.goldOnHit', {
          'n': amount.toStringAsFixed(1),
        }),
      };
}
