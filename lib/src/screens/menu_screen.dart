import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../app_theme.dart';
import '../cart_controller.dart';
import '../config.dart';
import '../eater_api.dart';
import '../models.dart';
import '../services/phone_store.dart';
import '../services/ready_alert_service.dart';
import '../services/voice_order_service.dart';
import 'order_status_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _api = EaterApi();
  final _cart = CartController();
  final _voice = VoiceOrderService();
  final _phoneStore = PhoneStore();
  final _searchController = TextEditingController();

  MenuResponse? _menu;
  String? _selectedCategoryId;
  String? _tableToken;
  String? _error;
  bool _loading = true;
  bool _listening = false;
  bool _checkoutInProgress = false;

  @override
  void initState() {
    super.initState();
    _tableToken = _resolveTableToken();
    _loadMenu();
  }

  @override
  void dispose() {
    _cart.dispose();
    _searchController.dispose();
    unawaited(_voice.stop());
    super.dispose();
  }

  Future<void> _loadMenu() async {
    final token = _tableToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing table QR token';
      });
      return;
    }
    try {
      final menu = await _api.getMenu(token);
      setState(() {
        _menu = menu;
        _selectedCategoryId =
            menu.categories.isEmpty ? null : menu.categories.first.id;
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String? _resolveTableToken() {
    final uri = Uri.base;
    return uri.queryParameters['table_token'] ??
        uri.queryParameters['token'] ??
        const String.fromEnvironment('TABLE_TOKEN');
  }

  List<MenuItem> _visibleItems() {
    final menu = _menu;
    if (menu == null) {
      return [];
    }
    final query = _searchController.text.trim().toLowerCase();
    return menu.items.where((item) {
      final matchesCategory = query.isNotEmpty ||
          _selectedCategoryId == null ||
          item.categoryId == _selectedCategoryId;
      final matchesSearch =
          query.isEmpty || item.name.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _startVoiceSearch() async {
    setState(() => _listening = true);
    await _voice.listen(
      onWords: (words) {
        _searchController.text = words;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: words.length),
        );
        setState(() {});
      },
      onDone: () {
        if (mounted) {
          setState(() => _listening = false);
        }
      },
    );
  }

  Future<void> _checkout() async {
    final token = _tableToken;
    if (token == null || _cart.isEmpty || _checkoutInProgress) {
      return;
    }
    setState(() => _checkoutInProgress = true);
    final result = await showModalBottomSheet<_CheckoutResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CheckoutSheet(
          cart: _cart,
          phoneStore: _phoneStore,
        );
      },
    );
    if (result == null) {
      if (mounted) {
        setState(() => _checkoutInProgress = false);
      }
      return;
    }
    try {
      final validatedCart = await _api.validateCart(
        tableToken: token,
        lines: _cart.lines,
      );
      if (!validatedCart.valid) {
        throw const EaterApiException(
          'Some cart items are unavailable. Please update your cart.',
          409,
        );
      }
      final session = await _api.initiatePayment(
        tableToken: token,
        phoneNumber: result.phone,
        lines: _cart.lines,
        idempotencyKey: const Uuid().v4(),
      );
      await _phoneStore.savePhone(result.phone);
      if (!mounted) {
        return;
      }
      if (session.paymentLink.isNotEmpty) {
        await launchUrl(
          Uri.parse(session.paymentLink),
          mode: LaunchMode.externalApplication,
        );
      }
      if (!session.demo) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complete payment with ${session.provider}. Waiting for confirmation.',
            ),
          ),
        );
        final status = await _waitForPaymentConfirmation(session.paymentId);
        if (!mounted) {
          return;
        }
        if (status?.orderId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Payment is still pending. Please check again soon.'),
            ),
          );
          return;
        }
        _cart.clear();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderStatusScreen(
              api: _api,
              orderId: status!.orderId!,
              initialStatus: 'preparing',
              readyAlertService: ReadyAlertService(),
            ),
          ),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo checkout: payment verification is simulated.'),
        ),
      );
      final verified = await _api.verifyPayment(
        paymentId: session.paymentId,
        gatewayReference: 'client-demo',
      );
      if (!mounted) {
        return;
      }
      _cart.clear();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderStatusScreen(
            api: _api,
            orderId: verified.orderId,
            initialStatus: verified.status,
            readyAlertService: ReadyAlertService(),
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _checkoutInProgress = false);
      }
    }
  }

  Future<PaymentStatus?> _waitForPaymentConfirmation(String paymentId) async {
    for (var attempt = 0; attempt < 45; attempt += 1) {
      final status = await _api.getPaymentStatus(paymentId);
      if (status.isPaid && status.orderId != null) {
        return status;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        return Scaffold(
          bottomNavigationBar: _cart.isEmpty
              ? null
              : SafeArea(
                  child: _CheckoutBar(
                    cart: _cart,
                    loading: _checkoutInProgress,
                    onCheckout: _checkout,
                  ),
                ),
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _loadMenu)
                    : _MenuContent(
                        menu: _menu!,
                        selectedCategoryId: _selectedCategoryId,
                        searchController: _searchController,
                        listening: _listening,
                        visibleItems: _visibleItems(),
                        cart: _cart,
                        onCategorySelected: (id) {
                          setState(() => _selectedCategoryId = id);
                        },
                        onSearchChanged: () => setState(() {}),
                        onVoicePressed: _startVoiceSearch,
                      ),
          ),
        );
      },
    );
  }
}

class _MenuContent extends StatelessWidget {
  const _MenuContent({
    required this.menu,
    required this.selectedCategoryId,
    required this.searchController,
    required this.listening,
    required this.visibleItems,
    required this.cart,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.onVoicePressed,
  });

  final MenuResponse menu;
  final String? selectedCategoryId;
  final TextEditingController searchController;
  final bool listening;
  final List<MenuItem> visibleItems;
  final CartController cart;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onSearchChanged;
  final VoidCallback onVoicePressed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConfig.restaurantName,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Table ${menu.tableNumber ?? '-'}',
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    _CartPill(count: cart.count, total: cart.total),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search dishes',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Voice order',
                      onPressed: onVoicePressed,
                      icon: Icon(
                        listening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        color: listening ? AppTheme.chili : AppTheme.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: menu.categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final category = menu.categories[index];
                      final selected = category.id == selectedCategoryId;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(category.name),
                        onSelected: (_) => onCategorySelected(category.id),
                        selectedColor: AppTheme.ink,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AppTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.line),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index.isOdd) {
                  return const SizedBox(height: 12);
                }
                final item = visibleItems[index ~/ 2];
                return _MenuItemTile(
                  item: item,
                  quantity: cart.quantityFor(item),
                  onAdd: () => cart.add(item),
                  onRemove: () => cart.remove(item),
                );
              },
              childCount:
                  visibleItems.isEmpty ? 0 : visibleItems.length * 2 - 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final MenuItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 86,
              height: 86,
              child: item.imageUrl == null || item.imageUrl!.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFFFE7D3),
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: AppTheme.saffron,
                      ),
                    )
                  : Image.network(item.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rs ${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppTheme.chili,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          quantity == 0
              ? IconButton.filled(
                  tooltip: 'Add',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                )
              : _Stepper(
                  quantity: quantity,
                  onAdd: onAdd,
                  onRemove: onRemove,
                ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.remove_rounded, color: Colors.white),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _CartPill extends StatelessWidget {
  const _CartPill({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        '$count - Rs ${total.toStringAsFixed(0)}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.cart,
    required this.loading,
    required this.onCheckout,
  });

  final CartController cart;
  final bool loading;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${cart.count} items - Rs ${cart.total.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton(
            onPressed: loading ? null : onCheckout,
            style: FilledButton.styleFrom(
              minimumSize: const Size(128, 48),
              backgroundColor: AppTheme.saffron,
            ),
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Pay now'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({
    required this.cart,
    required this.phoneStore,
  });

  final CartController cart;
  final PhoneStore phoneStore;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _phoneController = TextEditingController();
  bool _marketingConsent = true;

  @override
  void initState() {
    super.initState();
    widget.phoneStore.readPhone().then((phone) {
      if (mounted && phone != null) {
        _phoneController.text = phone;
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Checkout',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.call_rounded),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Demo mode: payment verification is simulated by this app after a payment session is created.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _marketingConsent,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() => _marketingConsent = value ?? false);
            },
            title: const Text('Send me restaurant offers and order updates'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final phone = _phoneController.text.trim();
              if (phone.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid phone number')),
                );
                return;
              }
              Navigator.of(context).pop(
                _CheckoutResult(
                  phone: phone,
                  marketingConsent: _marketingConsent,
                ),
              );
            },
            child: Text('Pay Rs ${widget.cart.total.toStringAsFixed(0)}'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutResult {
  const _CheckoutResult({
    required this.phone,
    required this.marketingConsent,
  });

  final String phone;
  final bool marketingConsent;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 54, color: AppTheme.chili),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
