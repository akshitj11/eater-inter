# Bawarchii Eater

Customer-facing Flutter interface opened from a restaurant table QR.

## Run

```powershell
flutter pub get
flutter run -d chrome --dart-define=EATER_API_BASE_URL=http://localhost:8000/api/eater
```

The app reads the QR table token from the URL:

```text
/?table_token=YOUR_TABLE_QR_TOKEN
```

## Backend Contract

This app is built against the existing `bawarchi-cloud` eater routes:

- `GET /menu?table_token=...`
- `POST /cart/validate`
- `POST /payment/initiate`
- `POST /payment/verify`
- `GET /orders/{order_id}`
- `GET /orders?phone=...`

No `bawarchi-cloud` route or database schema changes are required for the current implementation.
