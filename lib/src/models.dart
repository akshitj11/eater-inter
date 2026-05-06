class Category {
  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Category',
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.imageUrl,
  });

  final String id;
  final String? categoryId;
  final String name;
  final double price;
  final bool isAvailable;
  final String? imageUrl;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      name: json['name'] as String? ?? 'Menu item',
      price: _asDouble(json['price']),
      isAvailable: json['is_available'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
    );
  }
}

class MenuResponse {
  const MenuResponse({
    required this.tableId,
    required this.tableNumber,
    required this.categories,
    required this.items,
  });

  final String tableId;
  final String? tableNumber;
  final List<Category> categories;
  final List<MenuItem> items;

  factory MenuResponse.fromJson(Map<String, dynamic> json) {
    return MenuResponse(
      tableId: json['table_id'] as String,
      tableNumber: json['table_number'] as String?,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CartLine {
  const CartLine({
    required this.item,
    required this.quantity,
  });

  final MenuItem item;
  final int quantity;

  double get subtotal => item.price * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(item: item, quantity: quantity ?? this.quantity);
  }
}

class ValidatedCart {
  const ValidatedCart({
    required this.valid,
    required this.totalAmount,
  });

  final bool valid;
  final double totalAmount;

  factory ValidatedCart.fromJson(Map<String, dynamic> json) {
    return ValidatedCart(
      valid: json['valid'] as bool? ?? false,
      totalAmount: _asDouble(json['total_amount']),
    );
  }
}

class PaymentSession {
  const PaymentSession({
    required this.paymentId,
    required this.amount,
    required this.paymentLink,
    required this.idempotencyKey,
    required this.provider,
    required this.demo,
  });

  final String paymentId;
  final double amount;
  final String paymentLink;
  final String idempotencyKey;
  final String provider;
  final bool demo;

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      paymentId: json['payment_id'] as String,
      amount: _asDouble(json['amount']),
      paymentLink: json['payment_link'] as String? ?? '',
      idempotencyKey: json['idempotency_key'] as String,
      provider: json['provider'] as String? ?? 'demo',
      demo: json['demo'] as bool? ?? true,
    );
  }
}

class VerifyPaymentResponse {
  const VerifyPaymentResponse({
    required this.orderId,
    required this.status,
    required this.tableNumber,
    required this.totalAmount,
  });

  final String orderId;
  final String status;
  final String? tableNumber;
  final double totalAmount;

  factory VerifyPaymentResponse.fromJson(Map<String, dynamic> json) {
    return VerifyPaymentResponse(
      orderId: json['order_id'] as String,
      status: json['status'] as String? ?? 'preparing',
      tableNumber: json['table_number'] as String?,
      totalAmount: _asDouble(json['total_amount']),
    );
  }
}

class PaymentStatus {
  const PaymentStatus({
    required this.paymentId,
    required this.status,
    required this.orderId,
  });

  final String paymentId;
  final String status;
  final String? orderId;

  bool get isPaid => status.toLowerCase().trim() == 'paid';

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentStatus(
      paymentId: json['payment_id'] as String,
      status: json['status'] as String? ?? 'pending',
      orderId: json['order_id'] as String?,
    );
  }
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.status,
    required this.tableNumber,
    required this.totalAmount,
    required this.items,
  });

  final String id;
  final String status;
  final String? tableNumber;
  final double totalAmount;
  final List<OrderItem> items;

  bool get isReady {
    final normalized = status.toLowerCase().trim();
    return normalized == 'ready' ||
        normalized == 'served' ||
        normalized == 'completed' ||
        normalized == 'approved';
  }

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>? ?? json;
    return OrderDetail(
      id: order['id'] as String,
      status: order['status'] as String? ?? 'preparing',
      tableNumber: json['table_number'] as String?,
      totalAmount: _asDouble(order['total_amount']),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.status,
  });

  final String name;
  final int quantity;
  final double price;
  final String status;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: (json['name_snapshot'] as String?) ??
          (json['name'] as String?) ??
          'Item',
      quantity: json['quantity'] as int? ?? 0,
      price: _asDouble(json['price_snapshot'] ?? json['price']),
      status: json['status'] as String? ?? 'preparing',
    );
  }
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}
