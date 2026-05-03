import 'package:flutter/foundation.dart';

import 'models.dart';

class CartController extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList(growable: false);
  int get count => _lines.values.fold(0, (sum, line) => sum + line.quantity);
  double get total => _lines.values.fold(0, (sum, line) => sum + line.subtotal);
  bool get isEmpty => _lines.isEmpty;

  int quantityFor(MenuItem item) => _lines[item.id]?.quantity ?? 0;

  void add(MenuItem item) {
    final existing = _lines[item.id];
    if (existing == null) {
      _lines[item.id] = CartLine(item: item, quantity: 1);
    } else {
      _lines[item.id] = existing.copyWith(quantity: existing.quantity + 1);
    }
    notifyListeners();
  }

  void remove(MenuItem item) {
    final existing = _lines[item.id];
    if (existing == null) {
      return;
    }
    if (existing.quantity <= 1) {
      _lines.remove(item.id);
    } else {
      _lines[item.id] = existing.copyWith(quantity: existing.quantity - 1);
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }
}
