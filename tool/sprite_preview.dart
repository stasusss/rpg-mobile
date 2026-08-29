// Dev-only harness: renders every procedural actor into a contact sheet so the
// art can be reviewed without launching the game.
//
//   flutter test tool/sprite_preview.dart
//
// Writes build/sprite_preview.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/data/enemies_data.dart';
import 'package:idle_rpg/flame/character_sprites.dart';
import 'package:idle_rpg/models/item.dart';

const double cell = 260;
const int columns = 5;

void main() {
  test('render contact sheet', () async {
    final entries = <(String, ActorComponent)>[];

    for (final weapon in WeaponLook.values) {
      entries.add((
        weapon.name,
        PlayerComponent(height: cell * 0.62)
          ..look = PlayerLook(
            weapon: weapon,
            hasShield: weapon == WeaponLook.sword,
            hasHelmet: weapon == WeaponLook.axe,
          )
          ..healthFraction = 0.7,
      ));
    }

    // Swing keyframes: wind-up, contact and follow-through.
    for (final t in [0.10, 0.16, 0.22]) {
      final swinging = PlayerComponent(height: cell * 0.62)
        ..look = const PlayerLook(weapon: WeaponLook.sword, hasShield: true)
        ..healthFraction = 1.0
        ..attack();
      swinging.update(t);
      entries.add(('swing $t', swinging));
    }

    final seen = <String>{};
    for (final def in enemyCatalog.values) {
      final key = '${def.visual.plan.name}-${def.visual.horns}-'
          '${def.visual.wings}-${def.visual.hasWeapon}';
      if (!seen.add(key)) continue;
      entries.add((
        def.name,
        EnemyComponent(
              visual: def.visual,
              height: cell * 0.62 * def.visual.scale,
            )
            ..healthFraction = 0.55,
      ));
    }

    final rows = (entries.length / columns).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, columns * cell, rows * cell),
      Paint()..color = const Color(0xFF6E8FA8),
    );

    final label = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < entries.length; i++) {
      final (name, actor) = entries[i];
      final ox = (i % columns) * cell;
      final oy = (i ~/ columns) * cell;

      canvas.drawRect(
        Rect.fromLTWH(ox + 1, oy + 1, cell - 2, cell - 2),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke,
      );
      canvas.drawLine(
        Offset(ox, oy + cell * 0.88),
        Offset(ox + cell, oy + cell * 0.88),
        Paint()..color = const Color(0xFF4A6B4A),
      );

      canvas.save();
      // Actors draw with their feet at size.y and are anchored bottom-centre.
      canvas.translate(
        ox + cell / 2 - actor.size.x / 2,
        oy + cell * 0.88 - actor.size.y,
      );
      actor.render(canvas);
      canvas.restore();

      label
        ..text = TextSpan(
          text: name,
          style: const TextStyle(fontSize: 13, color: Colors.white),
        )
        ..layout();
      label.paint(canvas, Offset(ox + 8, oy + cell - 22));
    }

    final image = await recorder.endRecording().toImage(
      columns * cell.round(),
      rows * cell.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/sprite_preview.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.absolute.path}');
  });
}
