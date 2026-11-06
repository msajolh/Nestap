/// Every location in the app. Use these instead of string literals.
abstract final class Routes {
  static const splash = '/splash';
  static const signIn = '/sign-in';

  static const home = '/home';
  static const addDevice = '/home/add-device';
  static String device(String id) => '/home/devices/$id';

  static const scenes = '/scenes';
  static const profile = '/profile';
}
