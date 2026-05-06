import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class EaterApi {
  EaterApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUri = Uri.parse(baseUrl ?? AppConfig.apiBaseUrl);

  final http.Client _client;
  final Uri _baseUri;

  Future<MenuResponse> getMenu(String tableToken) async {
    final response = await _client.get(
      _uri('/menu', {'table_token': tableToken}),
    );
    return MenuResponse.fromJson(_decode(response));
  }

  Future<ValidatedCart> validateCart({
    required String tableToken,
    required List<CartLine> lines,
  }) async {
    final response = await _client.post(
      _uri('/cart/validate'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'table_token': tableToken,
        'items': _cartItems(lines),
      }),
    );
    return ValidatedCart.fromJson(_decode(response, allowConflict: true));
  }

  Future<PaymentSession> initiatePayment({
    required String tableToken,
    required String phoneNumber,
    required List<CartLine> lines,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      _uri('/payment/initiate'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'table_token': tableToken,
        'phone_number': phoneNumber,
        'cart_items': _cartItems(lines),
        'idempotency_key': idempotencyKey,
      }),
    );
    return PaymentSession.fromJson(_decode(response));
  }

  Future<VerifyPaymentResponse> verifyPayment({
    required String paymentId,
    String? gatewayReference,
  }) async {
    final response = await _client.post(
      _uri('/payment/verify'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'payment_id': paymentId,
        'gateway_reference': gatewayReference,
      }),
    );
    return VerifyPaymentResponse.fromJson(_decode(response));
  }

  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    final response = await _client.get(_uri('/payment/status/$paymentId'));
    return PaymentStatus.fromJson(_decode(response));
  }

  Future<OrderDetail> getOrder(String orderId) async {
    final response = await _client.get(_uri('/orders/$orderId'));
    return OrderDetail.fromJson(_decode(response));
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(
      path: '$basePath$path',
      queryParameters: query,
    );
  }

  Map<String, dynamic> _decode(
    http.Response response, {
    bool allowConflict = false,
  }) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final isAllowedConflict = allowConflict && response.statusCode == 409;
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (!isSuccess && !isAllowedConflict) {
      throw EaterApiException(
        body['error'] as String? ?? 'Request failed',
        response.statusCode,
      );
    }
    return body;
  }

  List<Map<String, dynamic>> _cartItems(List<CartLine> lines) {
    return lines
        .map((line) => {
              'menu_item_id': line.item.id,
              'quantity': line.quantity,
            })
        .toList();
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};
}

class EaterApiException implements Exception {
  const EaterApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
