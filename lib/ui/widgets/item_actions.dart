import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_manager.dart';
import '../../data/items_data.dart';
import '../../models/gear_score.dart';
import '../../models/item.dart';
import '../../providers/combat_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/player_provider.dart';
import '../theme.dart';
import 'item_sheet.dart';

/// Compact Equip / Upgrade / Salvage menu anchored to the tapped tile.
Future<void> showItemContextMenu(
  BuildContext context,
  WidgetRef ref,
  ItemDef item, {
  String? uid,
  EquipSlot? equippedSlot,
}) async {
  AudioManager.instance.play(SfxKind.click);
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    showItemSheet(context, item, uid: uid, equippedSlot: equippedSlot);
    return;
  }
  final origin = box.localToGlobal(Offset.zero);
  final l10n = ref.read(l10nProvider);
  final level = ref.read(playerProvider).level;
  final inventory = ref.read(inventoryProvider);
  final worn = item.slot == null ? null : inventory.equipped[item.slot!];
  final wornScore = worn == null ? -1.0 : gearScore(itemById(worn.itemId));
  final isUpgrade =
      item.isEquipment &&
      uid != null &&
      equippedSlot == null &&
      level >= item.levelReq &&
      gearScore(item) > wornScore;

  final choice = await showMenu<String>(
    context: context,
    color: AppColors.surfaceHigh,
    position: RelativeRect.fromLTRB(
      origin.dx,
      origin.dy,
      origin.dx + box.size.width,
      origin.dy + box.size.height,
    ),
    items: [
      if (equippedSlot != null)
        PopupMenuItem(value: 'unequip', child: Text(l10n.t('ui.unequip')))
      else if (uid != null && item.isEquipment && level >= item.levelReq)
        PopupMenuItem(value: 'equip', child: Text(l10n.t('ui.equip')))
      else if (uid != null && item.kind == ItemKind.consumable)
        PopupMenuItem(value: 'use', child: Text(l10n.t('ui.use'))),
      if (item.isEquipment && uid != null && equippedSlot == null)
        PopupMenuItem(
          value: isUpgrade ? 'upgrade' : 'details',
          child: Text(l10n.t('ui.upgrade')),
        ),
      if (uid != null && equippedSlot == null)
        PopupMenuItem(value: 'salvage', child: Text(l10n.t('ui.salvage'))),
    ],
  );
  if (!context.mounted || choice == null) return;

  final bag = ref.read(inventoryProvider.notifier);
  switch (choice) {
    case 'equip' || 'upgrade':
      bag.equip(uid!);
    case 'unequip':
      bag.unequip(equippedSlot!);
    case 'use':
      ref.read(combatProvider.notifier).usePotion(uid!);
    case 'salvage':
      final gold = bag.sell(uid!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('ui.soldFor', {'gold': '$gold'}))),
        );
      }
    case 'details':
      showItemSheet(context, item, uid: uid, equippedSlot: equippedSlot);
  }
}
