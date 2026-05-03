class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'BAWARCHI_CLOUD_URL',
    defaultValue: 'http://localhost:8080',
  );


  static const restaurantName = String.fromEnvironment(
    'RESTAURANT_NAME',
    defaultValue: 'Bawarchii',
  );
}
