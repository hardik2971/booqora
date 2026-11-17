import 'package:flutter/material.dart' hide Thumb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/theme.dart';
import '../../data/db.dart';
import '../../widgets/anim.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'storefront_cart.dart';
import 'storefront_data.dart';

class StorefrontPage extends StatefulWidget {
  final String slug;
  final String? productId;
  const StorefrontPage({super.key, required this.slug, this.productId});

  @override
  State<StorefrontPage> createState() => _StorefrontPageState();
}

class _StorefrontPageState extends State<StorefrontPage> {
  final _scaffold = GlobalKey<ScaffoldState>();
  late StoreData data = StoreData.of(widget.slug);
  final _scroll = ScrollController();
  String? _title;

  @override
  void initState() {
    super.initState();
    data.refreshIfStale();
  }

  @override
  void didUpdateWidget(covariant StorefrontPage old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) data = StoreData.of(widget.slug);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _setTitle(String t) {
    if (_title == t) return;
    _title = t;
    Browser.setTitle(t);
  }

  void openCart() => _scaffold.currentState?.openEndDrawer();

  void goHome() => context.go('/s/${widget.slug}');

  void openProduct(Doc p) => context.go('/s/${widget.slug}/p/${p.id}');

  void addToCart(Doc p, [int qty = 1]) {
    data.add(p, qty);
    if (data.str('addToCart', 'cart') == 'checkout') {
      openCart();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${p.s('name')} added to cart'),
          width: 420,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(label: 'View cart', textColor: storeLight(data.brand), onPressed: openCart),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        if (data.loading && data.store == null) return const _StoreLoading();
        if (data.error != null && data.store == null) {
          _setTitle('Online store');
          return _OfflinePage(title: 'We couldn\'t load this store', message: 'Please check your connection and try again.', onRetry: data.load);
        }
        if (data.offline) {
          _setTitle(data.missing ? 'Store not found' : data.name);
          return _OfflinePage(
            title: data.missing ? 'This store doesn\'t exist' : 'This store is currently offline',
            message: data.missing
                ? 'The link may be mistyped or the store may have moved.'
                : '${data.name} isn\'t taking online bookings right now. Please check back soon.',
            name: data.missing ? null : data.name,
            email: data.missing ? null : data.str('email'),
            phone: data.missing ? null : data.str('phone'),
          );
        }
        final pid = widget.productId;
        final product = pid == null ? null : data.product(pid);
        _setTitle(product == null ? (data.str('seoTitle').isNotEmpty ? data.str('seoTitle') : data.name) : '${product.s('name')} · ${data.name}');
        Widget body;
        if (data.lastOrder != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients && _scroll.offset > 0) {
              _scroll.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
            }
          });
          body = SuccessView(data: data, onContinue: () {
            data.clearSuccess();
            goHome();
          });
        } else if (pid != null) {
          body = product == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'Product not found',
                    message: 'This product is no longer available in the store.',
                    actionLabel: 'Browse products',
                    onAction: goHome,
                  ),
                )
              : _ProductDetail(key: ValueKey(pid), page: this, product: product);
        } else {
          body = _Home(page: this);
        }
        return Theme(
          data: storeTheme(Theme.of(context), data.brand),
          child: Scaffold(
            key: _scaffold,
            backgroundColor: const Color(0xFFFAFAFC),
            endDrawer: CartDrawer(data: data, onCheckout: () => showCheckout(context, data)),
            body: Column(children: [
              _TopBar(page: this),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (data.str('announcement').trim().isNotEmpty) _Announcement(text: data.str('announcement'), color: storeDark(data.brand)),
                    body,
                    _Footer(data: data),
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ---------------- Theme helpers ----------------

Color storeDark(Color c) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness * 0.5).clamp(0.0, 1.0)).toColor();
}

Color storeLight(Color c) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + 0.3).clamp(0.0, 0.92)).toColor();
}

ThemeData storeTheme(ThemeData base, Color brand) {
  final radius = BorderRadius.circular(10);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(primary: brand, secondary: storeDark(brand)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: brand, textStyle: const TextStyle(fontWeight: FontWeight.w600))),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: brand, width: 1.6)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: brand),
    checkboxTheme: base.checkboxTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand : Colors.transparent),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand : AppColors.muted)),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: brand.withValues(alpha: 0.12),
      labelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w500),
      side: const BorderSide(color: AppColors.border),
    ),
    datePickerTheme: DatePickerThemeData(
      todayForegroundColor: WidgetStateProperty.all(brand),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand : null),
    ),
  );
}

// ---------------- Chrome ----------------

class _TopBar extends StatelessWidget {
  final _StorefrontPageState page;
  const _TopBar({required this.page});

  @override
  Widget build(BuildContext context) {
    final data = page.data;
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 760;
    final logo = data.str('logoUrl');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x0A1C0938), blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 12, vertical: 10),
              child: Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: page.goHome,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (logo.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(logo, height: 36, fit: BoxFit.contain, errorBuilder: (_, _, _) => _Monogram(data: data)),
                        )
                      else
                        _Monogram(data: data),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: wide ? 260 : w * 0.42),
                        child: Text(data.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
                      ),
                    ]),
                  ),
                ),
                const Spacer(),
                if (wide) ...[
                  SizedBox(width: w > 1000 ? 340 : 240, child: _SearchBox(page: page)),
                  const SizedBox(width: 12),
                ],
                _CartButton(count: data.cartCount, color: data.brand, onTap: page.openCart),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  final StoreData data;
  const _Monogram({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [data.brand, storeDark(data.brand)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(data.name.isEmpty ? 'S' : data.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
      );
}

class _SearchBox extends StatefulWidget {
  final _StorefrontPageState page;
  const _SearchBox({required this.page});

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  late final _c = TextEditingController(text: widget.page.data.query);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: (v) {
        widget.page.data.setQuery(v);
        if (widget.page.widget.productId != null) widget.page.goHome();
      },
      decoration: InputDecoration(
        hintText: 'Search products',
        prefixIcon: const Icon(Icons.search, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        fillColor: const Color(0xFFF5F4F8),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _c.clear();
                  widget.page.data.setQuery('');
                },
              ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _CartButton({required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
        icon: const Icon(Icons.shopping_bag_outlined, size: 20),
        label: const Text('Cart'),
      ),
      if (count > 0)
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            key: ValueKey(count),
            constraints: const BoxConstraints(minWidth: 22),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color, width: 2),
            ),
            child: Text('$count', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ).animate(key: ValueKey(count)).scaleXY(begin: 0.4, end: 1, duration: 420.ms, curve: Curves.elasticOut),
        ),
    ]);
  }
}

class _Announcement extends StatelessWidget {
  final String text;
  final Color color;
  const _Announcement({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.campaign_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.4, end: 0, duration: 400.ms);
}

class _Footer extends StatelessWidget {
  final StoreData data;
  const _Footer({required this.data});

  @override
  Widget build(BuildContext context) {
    final email = data.str('email'), phone = data.str('phone');
    return Container(
      margin: const EdgeInsets.only(top: 48),
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 48, runSpacing: 24, children: [
              SizedBox(
                width: 360,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  if (data.str('description').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(data.str('description'), style: TextStyle(color: Colors.white.withValues(alpha: 0.65), height: 1.5)),
                  ],
                ]),
              ),
              if (email.isNotEmpty || phone.isNotEmpty)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (email.isNotEmpty) _FooterLink(icon: Icons.mail_outline, text: email, onTap: () => Browser.openUrl('mailto:$email')),
                  if (phone.isNotEmpty) _FooterLink(icon: Icons.phone_outlined, text: phone, onTap: () => Browser.openUrl('tel:$phone')),
                ]),
            ]),
            const SizedBox(height: 28),
            Divider(color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 8, alignment: WrapAlignment.spaceBetween, children: [
              Text('© ${DateTime.now().year} ${data.name}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5)),
              InkWell(
                onTap: () => Browser.openUrl(Browser.origin),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Powered by ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5)),
                  const Text('Booqora', style: TextStyle(color: AppColors.lavender, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _FooterLink({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      );
}

// ---------------- Home ----------------

class _Home extends StatelessWidget {
  final _StorefrontPageState page;
  const _Home({required this.page});

  @override
  Widget build(BuildContext context) {
    final data = page.data;
    final w = MediaQuery.sizeOf(context).width;
    final items = data.visibleProducts;
    final pad = w < 700 ? 16.0 : 24.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Hero(data: data),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 28, pad, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (w < 760) ...[_SearchBox(page: page), const SizedBox(height: 14)],
              if (data.collections.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip(data, null, 'All products'),
                    for (final c in data.collections) _chip(data, c.id, c.s('name')),
                  ]),
                ),
                const SizedBox(height: 20),
              ],
              Row(children: [
                Text(
                  data.collectionId == null
                      ? 'All products'
                      : data.collections.where((c) => c.id == data.collectionId).map((c) => c.s('name')).firstOrNull ?? 'Products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 10),
                Text('${items.length} ${items.length == 1 ? 'item' : 'items'}', style: const TextStyle(color: AppColors.muted)),
              ]),
              const SizedBox(height: 16),
              if (items.isEmpty)
                EmptyState(
                  icon: data.products.isEmpty ? Icons.storefront_outlined : Icons.search_off,
                  title: data.products.isEmpty ? 'Products coming soon' : 'No products found',
                  message: data.products.isEmpty ? 'This store hasn\'t published any products yet.' : 'Try a different search or collection.',
                )
              else
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth < 520 ? 1 : (c.maxWidth < 820 ? 2 : (c.maxWidth < 1100 ? 3 : 4));
                  final cw = (c.maxWidth - (cols - 1) * 18) / cols;
                  return Wrap(spacing: 18, runSpacing: 18, children: [
                    for (var i = 0; i < items.length; i++)
                      SizedBox(
                        width: cw,
                        child: ProductCard(
                          product: items[i],
                          data: data,
                          onOpen: () => page.openProduct(items[i]),
                          onAdd: () => page.addToCart(items[i]),
                        ).enter(i),
                      ),
                  ]);
                }),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _chip(StoreData data, String? id, String label) {
    final sel = data.collectionId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        labelStyle: TextStyle(color: sel ? data.brand : AppColors.inkSoft, fontWeight: FontWeight.w600),
        side: BorderSide(color: sel ? data.brand : AppColors.border),
        onSelected: (_) => data.setCollection(id),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final StoreData data;
  const _Hero({required this.data});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 760;
    final title = data.str('heroTitle').isNotEmpty ? data.str('heroTitle') : 'Rent from ${data.name}';
    final sub = data.str('heroSubtitle').isNotEmpty
        ? data.str('heroSubtitle')
        : (data.str('description').isNotEmpty ? data.str('description') : 'Choose your dates, pick your gear and request a booking in minutes.');
    final brand = data.brand;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [brand, storeDark(brand), const Color(0xFF1C0938)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(children: [
        Positioned(
          right: -80,
          top: -60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.9, end: 1.1, duration: 4.seconds, curve: Curves.easeInOut),
        ),
        Positioned(
          left: -60,
          bottom: -90,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: EdgeInsets.fromLTRB(narrow ? 16 : 24, narrow ? 32 : 56, narrow ? 16 : 24, narrow ? 28 : 48),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: narrow ? 30 : 44,
                            height: 1.1,
                            letterSpacing: -0.8,
                          )),
                ).enter(0),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: narrow ? 15 : 17, height: 1.5)),
                ).enter(1),
                const SizedBox(height: 26),
                PeriodPicker(data: data).enter(2),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// "Rent from / Rent until" card.
class PeriodPicker extends StatelessWidget {
  final StoreData data;
  final bool compact;
  const PeriodPicker({super.key, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final from = DateTimeField(
      label: 'Rent from',
      value: data.start,
      firstDate: DateTime.now(),
      onChanged: (v) {
        if (v != null) data.setPeriod(from: v);
      },
    );
    final until = DateTimeField(
      label: 'Rent until',
      value: data.end,
      firstDate: DateTime.now(),
      onChanged: (v) {
        if (v != null) data.setPeriod(until: v);
      },
    );
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: compact ? Border.all(color: AppColors.border) : null,
        boxShadow: compact ? null : const [BoxShadow(color: Color(0x331C0938), blurRadius: 30, offset: Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 460) return Column(children: [from, const SizedBox(height: 12), until]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: from),
            const SizedBox(width: 12),
            Expanded(child: until),
          ]);
        }),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: data.periodValid
              ? const SizedBox(width: double.infinity)
              : const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('The return date must be after the pickup date.', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
        ),
      ]),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Doc product;
  final StoreData data;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  const ProductCard({super.key, required this.product, required this.data, required this.onOpen, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final imgs = product.l<String>('imageUrls');
    final excerpt = product.s('excerpt').isNotEmpty ? product.s('excerpt') : product.s('description');
    return HoverLift(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 4 / 3, child: ProductImage(url: imgs.firstOrNull, brand: data.brand)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              SizedBox(
                height: 36,
                child: Text(excerpt, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: data.showPrices
                      ? Text(data.priceLabel(product), style: TextStyle(fontWeight: FontWeight.w800, color: data.brand, fontSize: 15))
                      : const Text('Price on request', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                ),
                IconButton.filledTonal(
                  tooltip: 'Add to cart',
                  style: IconButton.styleFrom(backgroundColor: data.brand.withValues(alpha: 0.1), foregroundColor: data.brand),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ProductImage extends StatelessWidget {
  final String? url;
  final Color brand;
  const ProductImage({super.key, required this.url, required this.brand});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [brand.withValues(alpha: 0.10), brand.withValues(alpha: 0.22)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Icon(Icons.inventory_2_outlined, size: 42, color: brand.withValues(alpha: 0.6)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) => progress == null ? child : const Skeleton(height: double.infinity, radius: 0),
    );
  }
}

// ---------------- Product detail ----------------

class _ProductDetail extends StatefulWidget {
  final _StorefrontPageState page;
  final Doc product;
  const _ProductDetail({super.key, required this.page, required this.product});

  @override
  State<_ProductDetail> createState() => _ProductDetailState();
}

class _ProductDetailState extends State<_ProductDetail> {
  int _image = 0;
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final data = widget.page.data;
    final p = widget.product;
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 900;
    final pad = w < 700 ? 16.0 : 24.0;
    final imgs = p.l<String>('imageUrls');
    final unit = data.unitPrice(p);
    final periods = data.periodsFor(p);
    final per = p.s('pricePer', 'day');
    final deposit = p.n('deposit');

    final gallery = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1.1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(_image),
              child: ProductImage(url: imgs.isEmpty ? null : imgs[_image.clamp(0, imgs.length - 1)], brand: data.brand),
            ),
          ),
        ),
      ),
      if (imgs.length > 1) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imgs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _image = i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: i == _image ? data.brand : AppColors.border, width: i == _image ? 2 : 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ProductImage(url: imgs[i], brand: data.brand),
                ),
              ),
            ),
          ),
        ),
      ],
    ]).enter(0);

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(p.s('name'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: w < 700 ? 26 : 32)).enter(1),
      const SizedBox(height: 10),
      if (data.showPrices)
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 10, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: c)),
            child: Text(data.money(unit),
                key: ValueKey(unit), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: data.brand, letterSpacing: -0.5)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              periods > 1 || data.perLabel(p).isNotEmpty ? 'for $periods $per${periods == 1 ? '' : 's'} · ${data.priceLabel(p)}' : 'per item',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ]).enter(2)
      else
        const Text('Price on request', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 16)),
      if (deposit > 0 && data.showPrices) ...[
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Text('Refundable security deposit ${data.money(deposit)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
        ]),
      ],
      const SizedBox(height: 20),
      PeriodPicker(data: data, compact: true).enter(3),
      const SizedBox(height: 18),
      Row(children: [
        _QtyStepper(qty: _qty, onChanged: (v) => setState(() => _qty = v)),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: data.periodValid ? () => widget.page.addToCart(p, _qty) : null,
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: Text(data.showPrices ? 'Add to cart · ${data.money(unit * _qty)}' : 'Add to cart'),
          ),
        ),
      ]).enter(4),
      if (p.s('description').isNotEmpty) ...[
        const SizedBox(height: 26),
        const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text(p.s('description'), style: const TextStyle(color: AppColors.inkSoft, height: 1.6)),
      ],
    ]);

    final cs = data.crossSell;
    final related = cs['enabled'] == true
        ? p.l<String>('crossSellIds').map(data.product).whereType<Doc>().take(((cs['maxItems'] as num?) ?? 4).toInt()).toList()
        : <Doc>[];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: widget.page.goHome, icon: const Icon(Icons.arrow_back, size: 18), label: const Text('All products')),
            ),
            const SizedBox(height: 10),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: gallery),
                const SizedBox(width: 40),
                Expanded(child: info),
              ])
            else ...[gallery, const SizedBox(height: 22), info],
            if (related.isNotEmpty) ...[
              const SizedBox(height: 44),
              Text((cs['title'] ?? 'Recommended products').toString(), style: Theme.of(context).textTheme.titleLarge),
              if ((cs['subtitle'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(cs['subtitle'].toString(), style: const TextStyle(color: AppColors.muted))),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth < 520 ? 1 : (c.maxWidth < 820 ? 2 : (c.maxWidth < 1100 ? 3 : 4));
                final cw = (c.maxWidth - (cols - 1) * 18) / cols;
                return Wrap(spacing: 18, runSpacing: 18, children: [
                  for (var i = 0; i < related.length; i++)
                    SizedBox(
                      width: cw,
                      child: ProductCard(
                        product: related[i],
                        data: data,
                        onOpen: () => widget.page.openProduct(related[i]),
                        onAdd: () => widget.page.addToCart(related[i]),
                      ).enter(i + 4),
                    ),
                ]);
              }),
            ],
          ]),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final bool small;
  const _QtyStepper({required this.qty, required this.onChanged, this.small = false});

  @override
  Widget build(BuildContext context) {
    final s = small ? 30.0 : 46.0;
    Widget btn(IconData i, VoidCallback? f) => SizedBox(
          width: s,
          height: s,
          child: IconButton(padding: EdgeInsets.zero, onPressed: f, icon: Icon(i, size: small ? 16 : 18)),
        );
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border), color: Colors.white),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, qty > 1 ? () => onChanged(qty - 1) : null),
        SizedBox(
          width: small ? 24 : 34,
          child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        btn(Icons.add, () => onChanged(qty + 1)),
      ]),
    );
  }
}

/// Public stepper for the cart drawer.
class QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  const QtyStepper({super.key, required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) => _QtyStepper(qty: qty, onChanged: onChanged, small: true);
}

// ---------------- Loading / offline ----------------

class _StoreLoading extends StatelessWidget {
  const _StoreLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Row(children: [Skeleton(height: 36, width: 36, radius: 10), SizedBox(width: 12), Skeleton(height: 16, width: 160), Spacer(), Skeleton(height: 40, width: 90)]),
        ),
        const Skeleton(height: 260, radius: 0),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth < 520 ? 1 : (c.maxWidth < 820 ? 2 : (c.maxWidth < 1100 ? 3 : 4));
              final cw = (c.maxWidth - (cols - 1) * 18) / cols;
              return Wrap(spacing: 18, runSpacing: 18, children: [
                for (var i = 0; i < cols; i++) SizedBox(width: cw, child: const Skeleton(height: 240, radius: 14)),
              ]);
            }),
          ),
        ),
      ]),
    );
  }
}

class _OfflinePage extends StatelessWidget {
  final String title;
  final String message;
  final String? name;
  final String? email;
  final String? phone;
  final VoidCallback? onRetry;
  const _OfflinePage({required this.title, required this.message, this.name, this.email, this.phone, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 40, offset: Offset(0, 20))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.storefront_outlined, size: 40, color: AppColors.primary),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -6, duration: 1800.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 22),
                  if (name != null) Text(name!, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, height: 1.5)),
                  if ((email ?? '').isNotEmpty || (phone ?? '').isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                      if ((email ?? '').isNotEmpty)
                        OutlinedButton.icon(onPressed: () => Browser.openUrl('mailto:$email'), icon: const Icon(Icons.mail_outline, size: 18), label: Text(email!)),
                      if ((phone ?? '').isNotEmpty)
                        OutlinedButton.icon(onPressed: () => Browser.openUrl('tel:$phone'), icon: const Icon(Icons.phone_outlined, size: 18), label: Text(phone!)),
                    ]),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Try again')),
                  ],
                  const SizedBox(height: 26),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Powered by ', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    const AppLogo(height: 18),
                  ]),
                ]),
              ),
            ).pop(),
          ),
        ),
      ),
    );
  }
}
