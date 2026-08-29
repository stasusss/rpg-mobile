import 'package:flutter/material.dart';

import 'stats.dart';

/// Named equipment collections. 2-piece and 4-piece bonuses stack.
enum ItemSetId {
  ashenWarden,
  shadowstalker,
  ironcladBehemoth,
  bloodthirster,
  archmageArcana,
  volcanicDrake;

  Color get color => switch (this) {
    ItemSetId.ashenWarden => const Color(0xFFFF8A50),
    ItemSetId.shadowstalker => const Color(0xFF818CF8),
    ItemSetId.ironcladBehemoth => const Color(0xFF90A4AE),
    ItemSetId.bloodthirster => const Color(0xFFE53935),
    ItemSetId.archmageArcana => const Color(0xFF7C4DFF),
    ItemSetId.volcanicDrake => const Color(0xFFFF6D00),
  };
}

@immutable
class ItemSetDef {
  const ItemSetDef({
    required this.id,
    required this.pieceIds,
    required this.twoPiece,
    required this.fourPiece,
    this.twoThorns = 0,
    this.fourThorns = 0,
  });

  final ItemSetId id;
  final List<String> pieceIds;
  final StatBundle twoPiece;
  final StatBundle fourPiece;

  /// Extra damage reflection granted at the 2 / 4 piece breakpoints.
  final double twoThorns;
  final double fourThorns;
}

@immutable
class SetProgress {
  const SetProgress({required this.def, required this.equipped});

  final ItemSetDef def;
  final int equipped;

  int get max => def.pieceIds.length;
  bool get hasTwo => equipped >= 2;
  bool get hasFour => equipped >= 4;
  int get breakpoint => hasFour
      ? 4
      : hasTwo
      ? 2
      : 0;

  StatBundle get bundle {
    var out = StatBundle.empty;
    if (hasTwo) out = out + def.twoPiece;
    if (hasFour) out = out + def.fourPiece;
    return out;
  }

  double get thorns =>
      (hasTwo ? def.twoThorns : 0) + (hasFour ? def.fourThorns : 0);
}
