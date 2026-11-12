import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_text.dart';
import '../../core/utils/unit_formatter.dart';
import '../../core/utils/weather_codes.dart';
import '../../models/air_quality.dart';
import '../../models/recommendation.dart';
import '../../models/weather_forecast.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/load_status.dart';
import '../../providers/location_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/weather_provider.dart';
import '../../services/weather_repository.dart';
import '../../widgets/activity_selector.dart';
import '../../widgets/app_card.dart';
import '../../widgets/image_placeholder.dart';
import '../../widgets/location_header.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_extensions.dart';
import '../air_quality/air_quality_screen.dart';
import '../forecast/forecast_screen.dart';
import '../location/location_search_screen.dart';

/// Pantalla de inicio: clima actual, actividad y mejor horario sugerido.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final weather = context.watch<WeatherProvider>();
    final settings = context.watch<SettingsProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final location = locationProvider.current;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => weather.refresh(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LocationChip(),
                    ),
                  ),
                  if (location != null)
                    IconButton(
                      tooltip: favorites.isLocationFavorite(location)
                          ? 'Quitar ubicación de favoritos'
                          : 'Guardar ubicación en favoritos',
                      onPressed: () => favorites.toggleLocation(location),
                      icon: Icon(
                        favorites.isLocationFavorite(location)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: favorites.isLocationFavorite(location)
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              if (locationProvider.isDemo && !locationProvider.isInitializing) ...[
                const SizedBox(height: 12),
                InfoBanner.caution(
                  message:
                      'Estás viendo la ubicación de demostración (${location?.name ?? 'Quito'}). ${locationProvider.notice ?? ''}'
                          .trim(),
                  action: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      foregroundColor: AppColors.onCautionSoft,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LocationSearchScreen(),
                      ),
                    ),
                    child: const Text('Elegir mi ubicación'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ..._content(context, locationProvider, weather, settings),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    LocationProvider locationProvider,
    WeatherProvider weather,
    SettingsProvider settings,
  ) {
    final bundle = weather.bundle;

    if (bundle == null) {
      if (weather.status == LoadStatus.error) {
        return [
          SizedBox(
            height: 380,
            child: ErrorView(
              message: weather.errorMessage ?? 'Inténtalo de nuevo.',
              onRetry: () => weather.refresh(force: true),
            ),
          ),
        ];
      }
      return [
        SizedBox(
          height: 380,
          child: LoadingView(
            message: locationProvider.isInitializing
                ? 'Buscando tu ubicación…'
                : 'Consultando el pronóstico…',
          ),
        ),
      ];
    }

    final formatter = settings.formatter;
    final upcoming = weather.upcomingRecommendation(settings.activity);

    return [
      if (weather.refreshError != null) ...[
        InfoBanner.caution(
          message:
              'No se pudo actualizar: ${weather.refreshError}. Se muestran los últimos datos obtenidos.',
        ),
        const SizedBox(height: 12),
      ],
      _CurrentWeatherCard(
        bundle: bundle,
        formatter: formatter,
        now: weather.nowAtLocation,
      ),
      const SizedBox(height: 16),
      ActivitySelector(
        selected: settings.activity,
        onChanged: settings.setActivity,
      ),
      const SizedBox(height: 16),
      _RecommendationCard(
        recommendation: upcoming,
        activityLabel: settings.activity.label,
        today: weather.todayAtLocation,
      ),
      const SizedBox(height: 16),
      _QuickAccessRow(bundle: bundle, now: weather.nowAtLocation),
      const SizedBox(height: 16),
      const LastUpdatedBar(),
      const SizedBox(height: 4),
      const Text(
        'Las puntuaciones son una orientación basada en pronósticos y no garantizan seguridad ni sustituyen el consejo médico.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
      ),
    ];
  }
}

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({
    required this.bundle,
    required this.formatter,
    required this.now,
  });

  final ForecastBundle bundle;
  final UnitFormatter formatter;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final weather = bundle.weather;
    final current = weather.current;
    final HourlyWeather? hourNow = now == null ? null : weather.hourAt(now!);

    final temperature = current?.temperature ?? hourNow?.temperature;
    final apparent = current?.apparentTemperature ?? hourNow?.apparentTemperature;
    final wind = current?.windSpeed ?? hourNow?.windSpeed;
    final code = current?.weatherCode ?? hourNow?.weatherCode;
    final condition = WeatherCondition.fromCode(code, isDay: current?.isDay ?? true);
    final uv = hourNow?.uvIndex;
    final rain = hourNow?.precipitationProbability;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.forest, AppColors.forestSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Imagen de cabecera opcional (assets/images/home_header.jpg).
          const Positioned.fill(
            child: OptionalBackdropImage(assetPath: AppAssets.homeHeader),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.forest.withValues(alpha: 0.35),
                    AppColors.forest.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateText.fullDate(now ?? weather.nowAtLocation()),
                            style: const TextStyle(color: AppColors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatter.temperature(temperature),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 68,
                              fontWeight: FontWeight.w300,
                              height: 1.05,
                            ),
                          ),
                          Text(
                            condition.description,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(condition.icon, size: 72, color: AppColors.white),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatPill(
                      icon: Icons.thermostat_rounded,
                      text: 'Sensación ${formatter.temperature(apparent)}',
                    ),
                    _StatPill(icon: Icons.air_rounded, text: formatter.wind(wind)),
                    if (rain != null)
                      _StatPill(
                        icon: Icons.water_drop_outlined,
                        text: 'Lluvia ${formatter.percent(rain)}',
                      ),
                    if (uv != null)
                      _StatPill(
                        icon: Icons.wb_sunny_outlined,
                        text: 'UV ${formatter.uv(uv)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.activityLabel,
    required this.today,
  });

  final DayRecommendation? recommendation;
  final String activityLabel;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    final window = rec?.bestWindow;

    if (rec == null || window == null || rec.bestHour == null) {
      return const AppCard(
        child: Text(
          'No hay datos suficientes para recomendar un horario con la información disponible.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final dayLabel =
        today == null ? '' : DateText.relativeDay(rec.date, today!).toLowerCase();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recomendación para $activityLabel',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ScoreBadge(
                score: window.averageScore,
                category: window.category,
                size: 72,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mejor horario sugerido',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateText.capitalize(dayLabel)}, ${DateText.hourRange(window.start, window.end)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    CategoryChip(category: window.category),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(rec.bestHour!.summary, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                context.read<WeatherProvider>().selectDate(rec.date);
                context.read<NavigationProvider>().goTo(NavigationProvider.recommendations);
              },
              icon: const Icon(Icons.insights_rounded),
              label: const Text('Ver todos los horarios'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow({required this.bundle, required this.now});

  final ForecastBundle bundle;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final air = bundle.airQuality;
    double? aqi = air?.current?.usAqi;
    if (aqi == null && air != null && now != null) {
      aqi = air.hourAt(now!)?.usAqi;
    }
    final category = AqiCategory.fromUsAqi(aqi);

    return Row(
      children: [
        Expanded(
          child: _QuickTile(
            icon: Icons.calendar_month_rounded,
            title: 'Pronóstico',
            subtitle: '5 días',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ForecastScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickTile(
            icon: Icons.masks_rounded,
            title: 'Aire',
            subtitle: aqi == null
                ? 'Sin datos'
                : 'AQI ${aqi.round()} · ${category?.label ?? ''}',
            accent: category?.color,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AirQualityScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickTile(
            icon: Icons.explore_rounded,
            title: 'Lugares',
            subtitle: 'Cerca de ti',
            onTap: () =>
                context.read<NavigationProvider>().goTo(NavigationProvider.explore),
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (accent ?? AppColors.forestSecondary).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AppColors.forest),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
