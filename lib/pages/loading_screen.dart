import 'package:material_ui/material_ui.dart';

/// Static startup screen: a white page with the SeeRuta icon centred.
///
/// Shown from the first Flutter frame, for at least three seconds, until
/// [StartupScreen] has loaded the route catalogue and prepared the map.
/// No permission prompts run during it; each feature asks when used.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  /// Same artwork as the launcher icon (`flutter_launcher_icons`).
  static const String iconAsset = 'assets/icon/ruta-icon.png';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(36)),
          child: Image(
            image: AssetImage(iconAsset),
            width: 160,
            height: 160,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
