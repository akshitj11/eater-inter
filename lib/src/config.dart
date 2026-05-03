class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'EATER_API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/eater',
  );

  static const restaurantName = String.fromEnvironment(
    'RESTAURANT_NAME',
    defaultValue: 'Bawarchii',
  );
}
