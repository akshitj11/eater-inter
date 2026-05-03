import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../eater_api.dart';
import '../models.dart';
import '../services/ready_alert_service.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({
    super.key,
    required this.api,
    required this.orderId,
    required this.initialStatus,
    required this.readyAlertService,
  });

  final EaterApi api;
  final String orderId;
  final String initialStatus;
  final ReadyAlertService readyAlertService;

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  Timer? _timer;
  OrderDetail? _order;
  String? _error;
  bool _buzzed = false;

  @override
  void initState() {
    super.initState();
    _order = OrderDetail(
      id: widget.orderId,
      status: widget.initialStatus,
      tableNumber: null,
      totalAmount: 0,
      items: const [],
    );
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final order = await widget.api.getOrder(widget.orderId);
      if (!mounted) {
        return;
      }
      setState(() {
        _order = order;
        _error = null;
      });
      if (order.isReady && !_buzzed) {
        _buzzed = true;
        await widget.readyAlertService.buzz();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final ready = order?.isReady ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order status'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: ready ? const Color(0xFFE9FFF4) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ready ? AppTheme.success : AppTheme.line,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      ready
                          ? Icons.notifications_active_rounded
                          : Icons.local_fire_department_rounded,
                      size: 52,
                      color: ready ? AppTheme.success : AppTheme.saffron,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      ready ? 'Your order is ready' : 'Kitchen is preparing it',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${order?.status ?? widget.initialStatus}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.chili),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Items',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: order?.items.length ?? 0,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = order!.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(item.status),
                      trailing: Text('x${item.quantity}'),
                    );
                  },
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
