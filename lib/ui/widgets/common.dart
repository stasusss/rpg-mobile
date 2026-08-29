import 'package:flutter/material.dart';

import '../../data/items_data.dart';
import '../../models/item.dart';
import '../theme.dart';

/// Rounded container used for every grouped block in the control panel.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? AppColors.outline),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: decoration,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small uppercase heading with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.icon});

  final String title;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.textFaint),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textMuted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Thin rounded progress bar with an optional inline caption.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 8,
    this.background = AppColors.surfaceHigh,
    this.label,
    this.labelStyle,
    this.duration = const Duration(milliseconds: 220),
  });

  final double fraction;
  final Color color;
  final double height;
  final Color background;
  final String? label;
  final TextStyle? labelStyle;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  Container(color: background),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.75), color],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (label != null)
            Text(
              label!,
              style:
                  labelStyle ??
                  TextStyle(
                    fontSize: height * 0.78,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.92),
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
            ),
        ],
      ),
    );
  }
}

/// Icon + value pill used for gold, gems and other counters.
class ResourceChip extends StatelessWidget {
  const ResourceChip({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
    this.fontSize = 11.5,
  });

  final IconData icon;
  final String value;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fontSize + 2.5, color: color),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

/// Rarity-framed item tile. Used in the bag grid and the equipment doll.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    this.quantity = 1,
    this.onTap,
    this.size = 48,
    this.badge,
    this.dimmed = false,
    this.showUpgradeHint = false,
  });

  final ItemDef item;
  final int quantity;
  final VoidCallback? onTap;
  final double size;

  /// Overrides the stack-count corner label.
  final String? badge;
  final bool dimmed;

  /// Shows a green arrow, e.g. when the item beats the equipped one.
  final bool showUpgradeHint;

  @override
  Widget build(BuildContext context) {
    final color = item.rarity.color;
    final rawLabel = badge ?? (quantity > 1 ? '$quantity' : null);
    final label = (rawLabel?.isEmpty ?? true) ? null : rawLabel;
    final glow = switch (item.rarity) {
      ItemRarity.common => 0.0,
      ItemRarity.uncommon => 2.5,
      ItemRarity.rare => 4.5,
      ItemRarity.epic => 6.5,
      ItemRarity.legendary => 8.5,
    };

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(
                  alpha: item.rarity == ItemRarity.common ? 0.55 : 0.95,
                ),
                width: item.rarity.index >= ItemRarity.epic.index ? 1.9 : 1.4,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.20), AppColors.surfaceAlt],
              ),
              boxShadow: glow <= 0
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.42),
                        blurRadius: glow,
                        spreadRadius: glow * 0.08,
                      ),
                    ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(item.icon, size: size * 0.5, color: color),
                ),
                if (label != null)
                  Positioned(
                    right: 2,
                    bottom: 1,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                    ),
                  ),
                if (showUpgradeHint)
                  const Positioned(
                    left: 1,
                    top: 1,
                    child: Icon(
                      Icons.arrow_drop_up,
                      size: 15,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty equipment slot placeholder.
class EmptySlotTile extends StatelessWidget {
  const EmptySlotTile({
    super.key,
    required this.slot,
    this.size = 48,
    this.onTap,
  });

  final EquipSlot slot;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline),
          ),
          child: Icon(
            slot.icon,
            size: size * 0.42,
            color: AppColors.textFaint.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// Centred hint for empty lists and grids.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 26, color: AppColors.textFaint),
            const SizedBox(height: 8),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

/// One `label : value` line, optionally with a delta suffix.
class StatLine extends StatelessWidget {
  const StatLine({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;

  /// Positive renders green with a `+`, negative red.
  final double? delta;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final d = delta ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.textFaint),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.text,
            ),
          ),
          if (d.abs() > 0.005)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text(
                '${d > 0 ? '+' : '-'}${formatStat(d.abs())}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: d > 0 ? AppColors.success : AppColors.hp,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact number formatting: 1234 -> 1.2k, 1500000 -> 1.5M.
String formatCount(num value) {
  final v = value.abs();
  final sign = value < 0 ? '-' : '';
  if (v < 1000) return '$sign${v.round()}';
  if (v < 1000000) {
    final k = v / 1000;
    return '$sign${k < 10 ? k.toStringAsFixed(1) : k.round()}k';
  }
  final m = v / 1000000;
  return '$sign${m < 10 ? m.toStringAsFixed(2) : m.toStringAsFixed(1)}M';
}

/// Trims trailing zeros for stat values: 12.0 -> 12, 1.25 -> 1.25.
String formatStat(double value) {
  if ((value - value.roundToDouble()).abs() < 0.005) {
    return value.round().toString();
  }
  return value.toStringAsFixed(value.abs() < 10 ? 2 : 1);
}

String formatPercent(double fraction, {int decimals = 1}) =>
    '${(fraction * 100).toStringAsFixed(decimals)}%';

String formatDuration(double seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m ${total % 60}s';
}

/// Shorthand used across tabs to look up an item without null checks.
ItemDef? itemOrNull(String id) => tryItemById(id);
