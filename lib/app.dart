import 'package:cupertino_ui/cupertino_ui.dart' as cupertino_ui;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/favorites_provider.dart';
import 'providers/location_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/places_provider.dart';
import 'providers/planner_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/weather_provider.dart';
import 'screens/main_shell.dart';
import 'services/air_quality_service.dart';
import 'services/api_client.dart';
import 'services/geocoding_service.dart';
import 'services/location_service.dart';
import 'services/overpass_service.dart';
import 'services/storage_service.dart';
import 'services/weather_repository.dart';
import 'services/weather_service.dart';

/// Raíz de la aplicación: crea los servicios y proveedores (inyección de
/// dependencias sencilla) y configura el tema Material 3 en español.
class AireListoApp extends StatefulWidget {
  const AireListoApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  State<AireListoApp> createState() => _AireListoAppState();
}

class _AireListoAppState extends State<AireListoApp> {
  late final ApiClient _apiClient = ApiClient();
  late final StorageService _storage = StorageService(widget.preferences);

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        Provider<StorageService>.value(value: _storage),
        Provider<WeatherRepository>(
          create: (_) => WeatherRepository(
            weatherService: WeatherService(_apiClient),
            airQualityService: AirQualityService(_apiClient),
          ),
        ),
        Provider<OverpassService>(create: (_) => OverpassService(_apiClient)),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(_storage),
        ),
        ChangeNotifierProvider<FavoritesProvider>(
          create: (_) => FavoritesProvider(_storage),
        ),
        ChangeNotifierProvider<PlannerProvider>(
          create: (_) => PlannerProvider(_storage),
        ),
        ChangeNotifierProvider<LocationProvider>(
          lazy: false,
          create: (_) => LocationProvider(
            locationService: const LocationService(),
            geocodingService: GeocodingService(_apiClient),
            storage: _storage,
          )..initialize(),
        ),
        // El pronóstico se actualiza solo cuando cambia la ubicación.
        ChangeNotifierProvider<WeatherProvider>(
          lazy: false,
          create: (context) => WeatherProvider(
            repository: context.read<WeatherRepository>(),
            locationProvider: context.read<LocationProvider>(),
          ),
        ),
        // Los lugares se consultan solo cuando el usuario abre "Explorar".
        ChangeNotifierProvider<PlacesProvider>(
          create: (context) => PlacesProvider(
            service: context.read<OverpassService>(),
            locationProvider: context.read<LocationProvider>(),
            settings: context.read<SettingsProvider>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          cupertino_ui.GlobalCupertinoLocalizations.delegate,
        ],
        home: const MainShell(),
      ),
    );
  }
}
