import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_rpg/app.dart';
import 'package:idle_rpg/providers/save_provider.dart';
import 'package:idle_rpg/ui/widgets/bottom_dock.dart';
import 'package:idle_rpg/ui/widgets/top_bar.dart';

Widget _app() => ProviderScope(
  overrides: [saveStoreProvider.overrideWithValue(MemorySaveStore())],
  child: const IdleRpgApp(),
);

Future<void> _openHub(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(180, 24));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('renders a clean canvas with icon hubs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: find.byType(TopBar),
        matching: find.textContaining('Lv 1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ash Grove'), findsWidgets);
    expect(find.byType(BottomDock), findsOneWidget);
    expect(find.byKey(const Key('hub-hero')), findsOneWidget);
    expect(find.byKey(const Key('hub-adventure')), findsOneWidget);
    expect(find.byKey(const Key('hub-craft')), findsOneWidget);
    expect(find.byKey(const Key('hub-skills')), findsOneWidget);
    expect(find.text('Gear'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('hubs open as modal sheets', (tester) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    await _openHub(tester, 'hub-hero');
    await tester.tap(find.text('Stats'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('altar-open')), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Weapon Mastery'), findsOneWidget);

    await _dismissSheet(tester);
    await _openHub(tester, 'hub-adventure');
    expect(find.text('Goblin Woods'), findsWidgets);
    expect(find.text('Charred Pelt'), findsWidgets);

    await tester.tap(find.text('Bestiary'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('discovered'), findsWidgets);

    await _dismissSheet(tester);
    await _openHub(tester, 'hub-craft');
    expect(find.text('Shop'), findsOneWidget);
    await tester.tap(find.text('Shop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.text('Time Scroll (1h)'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Time Scroll (1h)'), findsOneWidget);
    expect(find.text('XP Elixir'), findsOneWidget);
    expect(find.textContaining('1×'), findsWidgets);

    await _dismissSheet(tester);
    await _openHub(tester, 'hub-skills');
    expect(find.text('Might'), findsOneWidget);
    expect(find.text('Arcane'), findsOneWidget);
  });

  testWidgets('language toggle switches chrome and chapter 1 names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    await _openHub(tester, 'hub-hero');
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Українська'), findsOneWidget);

    await tester.tap(find.text('Українська'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byTooltip('Персонаж'), findsOneWidget);
    expect(find.byTooltip('Подорож'), findsOneWidget);
    expect(find.text('Попелястий Гай'), findsWidgets);

    await tester.tap(find.text('Спорядження'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Клинок Жарини'), findsWidgets);
    expect(find.text('Плащ Паломника'), findsWidgets);
  });

  testWidgets('the canvas claims leftover space above the dock', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    final column = tester.widget<Column>(
      find
          .descendant(of: find.byType(SafeArea), matching: find.byType(Column))
          .first,
    );
    final flexes = column.children.whereType<Expanded>().map((e) => e.flex);
    expect(flexes, [8, 92]);
    expect(find.byType(BottomDock), findsOneWidget);
  });
}
