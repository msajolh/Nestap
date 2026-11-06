/// Every location in the app. Use these instead of string literals.
abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';

  static const home = '/home';
  static const addDevice = '/home/add-device';
  static const notifications = '/home/notifications';
  static String device(String id) => '/home/devices/$id';
  static String deviceSettings(String id) => '/home/devices/$id/settings';
  static String deviceTimers(String id) => '/home/devices/$id/timers';
  static String deviceEnergy(String id) => '/home/devices/$id/energy';

  static const scenes = '/scenes';
  static String newRule({required bool automation}) =>
      '/scenes/new?kind=${automation ? 'automation' : 'scene'}';

  static const profile = '/profile';
  static const homeManagement = '/profile/home';
}
