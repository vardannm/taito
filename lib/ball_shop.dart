import 'package:flutter/material.dart';

import 'ball_cosmetics.dart';
import 'ball_world.dart';
import 'coin_store.dart';
import 'menu_design.dart';
import 'onboarding.dart';
import 'platforms.dart';
import 'premium_menu.dart' show MenuQuietButton;
import 'profile.dart';
import 'shop_catalog.dart';
import 'shop_product_card.dart';
import 'shop_product_sheet.dart';
import 'shop_product_state.dart';
import 'tutorial_spotlight.dart';

enum _Filter { all, affordable, owned, premium }

enum _Sort { price, descendingPrice, bonus }

class BallShop extends StatefulWidget {
  const BallShop({
    super.key,
    required this.profile,
    this.onTutorialChanged,
    this.onSkipTutorial,
  });
  final PlayerProfile profile;
  final VoidCallback? onTutorialChanged, onSkipTutorial;
  @override
  State<BallShop> createState() => _BallShopState();
}

class _BallShopState extends State<BallShop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int category = 0;
  double swipeDistance = 0;
  final exampleKey = GlobalKey();
  final scrolls = List.generate(3, (_) => ScrollController());
  final scrollOffsets = List.filled(3, 0.0);
  final searches = List.generate(3, (_) => TextEditingController());
  final filters = List.filled(3, _Filter.all);
  final sorts = List.filled(3, _Sort.price);
  final storage = PageStorageBucket();
  late final preview = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  bool get guiding =>
      !widget.profile.tutorialSeen &&
      [
        TutorialStep.shopBall,
        TutorialStep.shopPlatform,
      ].contains(widget.profile.tutorial.step);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.profile.tutorial.step == TutorialStep.shopPlatform) category = 1;
    revealExample();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPreview();
  }

  void syncPreview() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        ModalRoute.isCurrentOf(context) == false ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      preview.stop();
    } else if (!preview.isAnimating) {
      preview.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => syncPreview();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final scroll in scrolls) {
      scroll.dispose();
    }
    for (final search in searches) {
      search.dispose();
    }
    preview.dispose();
    super.dispose();
  }

  void changeCategory(int value) {
    if (guiding || value == category) return;
    if (scrolls[category].hasClients)
      scrollOffsets[category] = scrolls[category].offset;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => category = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && category == value && scrolls[value].hasClients) {
        final position = scrolls[value].position;
        scrolls[value].jumpTo(
          scrollOffsets[value].clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void finishSwipe(DragEndDetails details) {
    if (guiding) return;
    final velocity = details.primaryVelocity ?? 0;
    if (swipeDistance.abs() < 56 && velocity.abs() < 500) return;
    final direction = swipeDistance.abs() >= 56 ? swipeDistance : velocity;
    if (direction > 0 && category == 0) {
      Navigator.of(context).maybePop();
    } else {
      changeCategory((category + (direction < 0 ? 1 : -1)).clamp(0, 2));
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void revealExample() {
    if (!guiding) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = exampleKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, alignment: .8).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  void equipExample(ShopProduct product) {
    final p = widget.profile;
    if (product.ball != null) {
      p.selectBall(product.ball!);
    } else {
      p.selectPlatform(product.platform!);
    }
    setState(() {
      if (p.tutorial.step == TutorialStep.shopBall) {
        p.tutorial.step = TutorialStep.shopPlatform;
        category = 1;
      } else {
        p.tutorial.step = TutorialStep.shopBrowse;
      }
    });
    widget.onTutorialChanged?.call();
    revealExample();
  }

  Future<void> inspect(ShopProduct product) async {
    FocusManager.instance.primaryFocus?.unfocus();
    preview.stop();
    await showShopProduct(context, widget.profile, product);
    if (mounted) {
      refresh();
      syncPreview();
    }
  }

  String _worldSearch(ShopProduct item) =>
      '${BallWorld.of(item.ball!).name} ${BallWorld.of(item.ball!).description}'
          .toLowerCase();

  List<ShopProduct> products() {
    final p = widget.profile,
        query = searches[category].text.trim().toLowerCase();
    final items = shopCatalog[category].where((item) {
      if (query.isNotEmpty &&
          !'${item.name} ${item.description}'.toLowerCase().contains(query) &&
          !(item.ball != null && _worldSearch(item).contains(query)))
        return false;
      return switch (filters[category]) {
        _Filter.all => true,
        _Filter.affordable =>
          !item.ownedBy(p) &&
              !item.maxedFor(p) &&
              p.canAfford(item.priceFor(p)),
        _Filter.owned => item.ownedBy(p) || item.levelFor(p) > 0,
        _Filter.premium => item.premium,
      };
    }).toList();
    items.sort(
      (a, b) => switch (sorts[category]) {
        _Sort.price => a.price(a.levelFor(p)).compareTo(b.price(b.levelFor(p))),
        _Sort.descendingPrice =>
          b.price(b.levelFor(p)).compareTo(a.price(a.levelFor(p))),
        _Sort.bonus => b.bonus.compareTo(a.bonus),
      },
    );
    return items;
  }

  Widget collectionHeader(List<ShopProduct> items) {
    final p = widget.profile;
    final total = shopCatalog[category].length;
    final collected = category == 0
        ? p.ownedBalls.length
        : category == 1
        ? p.ownedPlatforms.length
        : shopCatalog[2].where((i) => i.maxedFor(p)).length;
    final featured = shopCatalog[0].where((i) => !i.ownedBy(p)).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [
            'A new ball. A new world.',
            'Precision, restyled.',
            'Built for a longer run.',
          ][category],
          style: const TextStyle(
            color: menuText,
            fontSize: 25,
            fontWeight: FontWeight.w500,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          category == 2
              ? '$collected of $total fully upgraded · Permanent benefits for Infinite.'
              : '$collected of $total collected · ${category == 0 ? 'Every ball includes its world.' : 'Your style. The same precise handling.'}',
          style: const TextStyle(color: menuMuted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 14),
        Semantics(
          label: '$collected of $total collected',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: collected / total,
              minHeight: 3,
              backgroundColor: menuLine,
              color: menuGold,
            ),
          ),
        ),
        if (!p.available)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Device storage is unavailable. Purchases only complete when they can be saved.',
              style: TextStyle(color: menuGold, fontSize: 12, height: 1.5),
            ),
          ),
        if (!guiding &&
            category == 0 &&
            featured != null &&
            searches[0].text.isEmpty &&
            filters[0] == _Filter.all) ...[
          const SizedBox(height: 22),
          ShopFeaturedWorld(
            product: featured,
            onPressed: () => inspect(featured),
            animation: MediaQuery.disableAnimationsOf(context) ? null : preview,
          ),
        ],
        if (!guiding) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('shop-search-$category'),
                  controller: searches[category],
                  onChanged: (_) => refresh(),
                  style: const TextStyle(color: menuText, fontSize: 13),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: menuLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: menuGold),
                    ),
                    hintText:
                        'Search ${['balls & worlds', 'platforms', 'upgrades'][category]}',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: menuMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    suffixIcon: searches[category].text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              searches[category].clear();
                              refresh();
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_Sort>(
                tooltip: 'Sort collection',
                initialValue: sorts[category],
                icon: const Icon(Icons.sort_rounded, color: menuGold),
                onSelected: (value) => setState(() => sorts[category] = value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _Sort.price,
                    child: Text('Price: low to high'),
                  ),
                  const PopupMenuItem(
                    value: _Sort.descendingPrice,
                    child: Text('Price: high to low'),
                  ),
                  if (category != 2)
                    const PopupMenuItem(
                      value: _Sort.bonus,
                      child: Text('Points bonus'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 5,
            children: [
              for (final filter in _Filter.values)
                if (category != 2 || filter != _Filter.premium)
                  ChoiceChip(
                    label: Text(switch (filter) {
                      _Filter.all => 'All',
                      _Filter.affordable => 'Can afford',
                      _Filter.owned => 'Owned',
                      _Filter.premium => 'Premium',
                    }),
                    selected: filters[category] == filter,
                    onSelected: (_) =>
                        setState(() => filters[category] = filter),
                    labelStyle: TextStyle(
                      color: filters[category] == filter
                          ? menuBackground
                          : menuMuted,
                      fontSize: 11,
                    ),
                    selectedColor: menuGold,
                    backgroundColor: menuPanel,
                    showCheckmark: false,
                  ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${items.length} ${category == 0
                ? 'worlds'
                : category == 1
                ? 'platforms'
                : 'upgrades'} · ${switch (sorts[category]) {
              _Sort.price => 'Price: low to high',
              _Sort.descendingPrice => 'Price: high to low',
              _Sort.bonus => 'Highest points bonus first',
            }}',
            style: const TextStyle(
              color: menuMuted,
              fontSize: 10,
              letterSpacing: .3,
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  Widget catalog() => LayoutBuilder(
    builder: (context, bounds) {
      final items = products();
      final minWidth = MediaQuery.textScalerOf(context).scale(11) > 16
          ? 280.0
          : 164.0;
      final columns = ((bounds.maxWidth - 24) / (minWidth + 12)).floor().clamp(
        1,
        3,
      );
      final rows = (items.length / columns).ceil();
      return ListView.builder(
        key: ValueKey('collection-$category'),
        controller: scrolls[category],
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
        itemCount: 1 + (items.isEmpty ? 1 : rows),
        itemBuilder: (context, index) {
          if (index == 0) return collectionHeader(items);
          if (items.isEmpty)
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 38,
                    color: menuMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No items here yet',
                    style: TextStyle(color: menuText, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try another search or browse the full collection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: menuMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: () {
                      searches[category].clear();
                      setState(() => filters[category] = _Filter.all);
                    },
                    child: const Text('Show all items'),
                  ),
                ],
              ),
            );
          final start = (index - 1) * columns;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 12),
                  Expanded(
                    child: start + col >= items.length
                        ? const SizedBox()
                        : Builder(
                            builder: (context) {
                              final item = items[start + col];
                              final example =
                                  guiding &&
                                  (item.ball == BallCosmetic.steel ||
                                      item.platform == PlatformStyle.classic);
                              return ShopProductCard(
                                product: item,
                                profile: widget.profile,
                                animation:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? null
                                    : preview,
                                tutorial: example,
                                tutorialKey: example ? exampleKey : null,
                                onInspect: () => inspect(item),
                                onAction: () => example
                                    ? equipExample(item)
                                    : inspect(item),
                                onCoinsChanged: refresh,
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );

  Widget collection() => MenuSurface(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF20383D), menuBackground],
          stops: [0, .55],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 18, 0),
                  child: Row(
                    children: [
                      MenuQuietButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Done shopping',
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ROLLRISE / COLLECTION',
                                style: TextStyle(
                                  color: menuGold,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Gear Shop',
                                style: TextStyle(
                                  color: menuText,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: WalletButton(
                              key: const ValueKey('wallet'),
                              profile: widget.profile,
                              onClosed: refresh,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your gear: x${formatBoost(widget.profile.equipmentMultiplier)} points',
                      key: const ValueKey('gear-total'),
                      style: const TextStyle(
                        color: menuMint,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: MenuTabs(
                    labels: const ['Balls', 'Platforms', 'Upgrades'],
                    selected: category,
                    minimal: true,
                    singleRow: true,
                    onChanged: changeCategory,
                  ),
                ),
                Expanded(
                  child: PageStorage(bucket: storage, child: catalog()),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('shop-swipe-area'),
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => swipeDistance = 0,
    onHorizontalDragUpdate: (details) => swipeDistance += details.delta.dx,
    onHorizontalDragEnd: finishSwipe,
    child: Stack(
      children: [
        collection(),
        if (guiding)
          TutorialSpotlight(
            title: widget.profile.tutorial.step == TutorialStep.shopBall
                ? 'Balls bring their world'
                : 'Platforms add points',
            icon: widget.profile.tutorial.step == TutorialStep.shopBall
                ? Icons.sports_baseball_rounded
                : Icons.horizontal_rule_rounded,
            lesson: widget.profile.tutorial.step.lesson,
            lessons: TutorialStep.lessons,
            message: widget.profile.tutorial.step == TutorialStep.shopBall
                ? 'Each ball comes with its own background, and stronger balls boost Infinite points. Tap Equip on your Steel starter.'
                : 'Platforms boost Infinite points too. Equip your starter rail, then browse the gear and upgrades.',
            blockOutside: true,
            onSkip: () {
              widget.onSkipTutorial?.call();
              refresh();
            },
            targets: (layer) {
              final rect = tutorialTarget(exampleKey, layer);
              return [if (rect != null) rect];
            },
          ),
      ],
    ),
  );
}
