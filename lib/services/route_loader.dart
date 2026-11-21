
import '../models/route.dart';
import 'route_database.dart';

/// Loads the jeepney route catalogue from the bundled SQLite database.
class RouteLoader {
  RouteLoader._();

  /// Load routes from `assets/data/routes.db`.
  static Future<List<JeepneyRoute>> load() async {
    return RouteDatabase.loadRoutes();
  }
}