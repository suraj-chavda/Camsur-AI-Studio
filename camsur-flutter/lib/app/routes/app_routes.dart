abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const shell = '/app';
  static const tools = '/tools';
  static const categories = '/categories';

  /// Separate prefix from [tools] — GetX breaks on `/tools` + `/tools/:slug`.
  static const toolDetail = '/tool/:slug';
  static const photoPreview = '/photo-preview';
  static const generationResult = '/generation-result';
  static const settings = '/settings';
  static const support = '/support';
  static const wallet = '/wallet';

  static String tool(String slug) => '/tool/$slug';
}
