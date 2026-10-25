/// Backend API endpoints. Matches camsur-backend `/api/v1`.
class ApiConstants {
  ApiConstants._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 120);

  // Auth
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const social = '/auth/social';
  static const refresh = '/auth/refresh';
  static const me = '/auth/me';

  // Tools (public)
  static const tools = '/tools';
  static const toolsCatalog = '/tools/catalog';
  static const toolsTrending = '/tools/trending';
  static const toolsBanners = '/tools/banners';
  static const toolsOnboarding = '/tools/onboarding';

  // Credits
  static const creditBalance = '/credits/balance';
  static const creditPackages = '/credits/packages';
  static const creditTransactions = '/credits/transactions';
  static const creditSettings = '/credits/settings';
  static const creditPurchases = '/credits/purchases';

  // Generations
  static const generations = '/generations';
  static const generationsFromPhoto = '/generations/from-photo';
  static const generationsMine = '/generations/mine';

  // Upload
  static const uploadImage = '/uploads/image';

  // Health
  static const health = '/health';
}
