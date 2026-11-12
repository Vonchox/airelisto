/// Rutas de los recursos gráficos que se incorporarán más adelante.
///
/// Ningún archivo es obligatorio: los widgets que los usan (ver
/// `widgets/image_placeholder.dart`) muestran un marcador de posición cuando
/// el archivo todavía no existe, de modo que la app nunca falla por una imagen
/// ausente. En `assets/README.md` está documentado dónde colocar cada archivo.
class AppAssets {
  AppAssets._();

  // Logotipo.
  static const String logo = 'assets/images/logo.png';

  // Imagen de cabecera de la pantalla Inicio.
  static const String homeHeader = 'assets/images/home_header.jpg';

  // Imágenes por actividad.
  static const String activityWalking = 'assets/images/activity_walking.jpg';
  static const String activityRunning = 'assets/images/activity_running.jpg';
  static const String activityCycling = 'assets/images/activity_cycling.jpg';

  // Imagen genérica para el detalle de un lugar.
  static const String placeDefault = 'assets/images/place_default.jpg';

  // Ilustraciones de estados vacíos.
  static const String emptyPlans = 'assets/images/empty_plans.png';
  static const String emptyPlaces = 'assets/images/empty_places.png';
  static const String emptyFavorites = 'assets/images/empty_favorites.png';
}
