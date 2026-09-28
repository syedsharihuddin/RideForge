/// Map style endpoints are kept separate from the renderer so the provider
/// can be replaced without changing RideForge's location or tracking code.
class MapStyleConfig {
  static const String darkStyleUrl = String.fromEnvironment(
    'RIDEFORGE_MAP_DARK_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/dark',
  );

  static const String lightStyleUrl = String.fromEnvironment(
    'RIDEFORGE_MAP_LIGHT_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/positron',
  );
}
