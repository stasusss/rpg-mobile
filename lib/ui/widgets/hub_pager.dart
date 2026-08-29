import 'package:flutter/material.dart';

import '../theme.dart';

/// Swipeable inner pages for a hub. Replaces nested micro-tabs with a
/// 48px chip strip and a [TabBarView].
class HubPager extends StatefulWidget {
  const HubPager({
    super.key,
    required this.labels,
    required this.pages,
  });

  final List<String> labels;
  final List<Widget> pages;

  @override
  State<HubPager> createState() => _HubPagerState();
}

class _HubPagerState extends State<HubPager>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.pages.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: TabBar(
              controller: _tabs,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold),
              ),
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                for (final label in widget.labels)
                  Tab(
                    height: 48,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: widget.pages),
        ),
      ],
    );
  }
}
