import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_text.dart';
import '../../models/air_quality.dart';
import '../../providers/load_status.dart';
import '../../providers/weather_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/location_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_extensions.dart';

/// Calidad del aire (escala US AQI), partículas PM2.5/PM10 y pronóstico horario.
class AirQualityScreen extends StatelessWidget {
  const AirQualityScreen({super.key});

  // Guías de calidad del aire de la OMS 2021 (promedio de 24 horas), en µg/m³.
  static const double _whoPm25 = 15;
  static const double _whoPm10 = 45;

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final bundle = weather.bundle;

    Widget body;
    if (bundle == null) {
      body = weather.status == LoadStatus.error
          ? ErrorView(
              message: weather.errorMessage ?? 'Inténtalo de nuevo.',
              onRetry: () => weather.refresh(force: true),
            )
          : const LoadingView(message: 'Consultando la calidad del aire…');
    } else if (bundle.airQuality == null || !bundle.airQuality!.hasAqi) {
      body = ErrorView(
        icon: Icons.masks_rounded,
        title: 'Sin datos de calidad del aire',
        message: bundle.airQualityError ??
            'No hay información de calidad del aire disponible para esta ubicación.',
        onRetry: () => weather.refresh(force: true),
      );
    } else {
      body = _content(context, weather, bundle.airQuality!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Calidad del aire')),
      body: body,
    );
  }

  Widget _content(BuildContext context, WeatherProvider weather, AirQualityData air) {
    final now = weather.nowAtLocation;
    final current = air.current ?? (now == null ? null : air.hourAt(now));
    // Si el dato actual no trae AQI, se intenta con la hora vigente.
    final hourNow = now == null ? null : air.hourAt(now);
    final aqi = current?.usAqi ?? hourNow?.usAqi;
    final pm25 = current?.pm25 ?? hourNow?.pm25;
    final pm10 = current?.pm10 ?? hourNow?.pm10;
    final category = AqiCategory.fromUsAqi(aqi);

    final upcoming = air.hourly
        .where((h) => now == null || !h.time.isBefore(DateTime.utc(now.year, now.month, now.day, now.hour)))
        .take(24)
        .toList();

    return RefreshIndicator(
      onRefresh: () => weather.refresh(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Align(alignment: Alignment.centerLeft, child: LocationChip()),
          const SizedBox(height: 12),
          if (category != null) _CurrentAqiCard(aqi: aqi!, category: category),
          if (category != null && category.needsCaution) ...[
            const SizedBox(height: 12),
            InfoBanner.caution(
              message:
                  'Precaución: ${category.advice} Considera elegir otro horario o una actividad más suave.',
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ParticleTile(label: 'PM2.5', value: pm25, whoGuide: _whoPm25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ParticleTile(label: 'PM10', value: pm10, whoGuide: _whoPm10),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Próximas 24 horas (US AQI)'),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const Text(
              'No hay pronóstico horario disponible.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            AppCard(child: _HourlyBars(hours: upcoming)),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Escala US AQI'),
          const SizedBox(height: 10),
          const AppCard(child: _ScaleLegend()),
          const SizedBox(height: 16),
          const Text(
            'Fuente: Open-Meteo Air Quality API (datos modelados, CC BY 4.0). El índice se muestra con la escala estadounidense (US AQI). Los valores son aproximados y pueden diferir de las estaciones de medición locales.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CurrentAqiCard extends StatelessWidget {
  const _CurrentAqiCard({required this.aqi, required this.category});

  final double aqi;
  final AqiCategory category;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: category.softColor,
              shape: BoxShape.circle,
              border: Border.all(color: category.color, width: 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${aqi.round()}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: category.onSoftColor,
                    height: 1,
                  ),
                ),
                Text(
                  'US AQI',
                  style: TextStyle(fontSize: 11, color: category.onSoftColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  category.advice,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticleTile extends StatelessWidget {
  const _ParticleTile({
    required this.label,
    required this.value,
    required this.whoGuide,
  });

  final String label;
  final double? value;
  final double whoGuide;

  @override
  Widget build(BuildContext context) {
    final ratio = value == null ? null : value! / whoGuide;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value == null ? '–' : value!.toStringAsFixed(1),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'µg/m³',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ratio == null
                ? 'Sin dato'
                : (ratio <= 1
                    ? 'Dentro de la guía de la OMS (${whoGuide.round()} µg/m³, 24 h)'
                    : '${ratio.toStringAsFixed(1)}× la guía de la OMS (${whoGuide.round()} µg/m³, 24 h)'),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _HourlyBars extends StatelessWidget {
  const _HourlyBars({required this.hours});

  final List<AirQualityHour> hours;

  @override
  Widget build(BuildContext context) {
    const maxAqi = 200.0;
    const maxBar = 90.0;
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hour = hours[index];
          final aqi = hour.usAqi;
          final category = AqiCategory.fromUsAqi(aqi);
          final height = aqi == null
              ? 6.0
              : (aqi / maxAqi * maxBar).clamp(6.0, maxBar).toDouble();
          return Semantics(
            label:
                '${DateText.hour(hour.time)}, AQI ${aqi?.round() ?? 'sin dato'}, ${category?.label ?? ''}',
            child: SizedBox(
              width: 34,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    aqi == null ? '–' : '${aqi.round()}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: category?.color ?? AppColors.outline,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateText.two(hour.time.hour),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScaleLegend extends StatelessWidget {
  const _ScaleLegend();

  static const Map<AqiCategory, String> _ranges = {
    AqiCategory.good: '0–50',
    AqiCategory.moderate: '51–100',
    AqiCategory.unhealthySensitive: '101–150',
    AqiCategory.unhealthy: '151–200',
    AqiCategory.veryUnhealthy: '201–300',
    AqiCategory.hazardous: '301 o más',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in _ranges.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: entry.key.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(entry.key.label)),
                Text(
                  entry.value,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
