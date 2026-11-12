import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_text.dart';
import '../../core/utils/unit_formatter.dart';
import '../../core/utils/weather_codes.dart';
import '../../models/recommendation.dart';
import '../../models/weather_forecast.dart';
import '../../providers/load_status.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/weather_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/location_header.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_extensions.dart';

/// Pronóstico de cinco días con detalle por horas y acceso a las
/// recomendaciones de cada día.
class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  DateTime? _expanded;

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final settings = context.watch<SettingsProvider>();
    final bundle = weather.bundle;
    final formatter = settings.formatter;

    Widget body;
    if (bundle == null) {
      body = weather.status == LoadStatus.error
          ? ErrorView(
              message: weather.errorMessage ?? 'Inténtalo de nuevo.',
              onRetry: () => weather.refresh(force: true),
            )
          : const LoadingView(message: 'Consultando el pronóstico…');
    } else {
      final today = weather.todayAtLocation;
      final missing = bundle.weather.incompleteVariables;
      body = RefreshIndicator(
        onRefresh: () => weather.refresh(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: LocationChip()),
            const SizedBox(height: 12),
            if (missing.isNotEmpty) ...[
              InfoBanner.caution(
                message:
                    'Algunos datos no están disponibles (${missing.join(', ')}). Las puntuaciones usan solo la información recibida.',
              ),
              const SizedBox(height: 12),
            ],
            for (final day in bundle.weather.daily)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayCard(
                  day: day,
                  today: today,
                  weather: bundle.weather,
                  formatter: formatter,
                  expanded: _expanded != null &&
                      DateText.isSameDay(_expanded!, day.date),
                  onToggle: () => setState(() {
                    final isOpen =
                        _expanded != null && DateText.isSameDay(_expanded!, day.date);
                    _expanded = isOpen ? null : day.date;
                  }),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'Datos meteorológicos: Open-Meteo.com (CC BY 4.0). Los pronósticos pueden cambiar.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pronóstico de 5 días')),
      body: body,
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.today,
    required this.weather,
    required this.formatter,
    required this.expanded,
    required this.onToggle,
  });

  final DailyWeather day;
  final DateTime? today;
  final WeatherForecast weather;
  final UnitFormatter formatter;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final provider = context.read<WeatherProvider>();
    final condition = WeatherCondition.fromCode(day.weatherCode);
    final dayLabel = today == null
        ? DateText.capitalize(DateText.weekday(day.date))
        : DateText.relativeDay(day.date, today!);
    final recommendation = provider.recommendationFor(settings.activity, day.date);
    final window = recommendation?.bestWindow;
    final isSelected = provider.selectedDate != null &&
        DateText.isSameDay(provider.selectedDate!, day.date);

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onToggle,
      color: isSelected ? AppColors.mint : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(condition.icon, size: 36, color: AppColors.forest),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayLabel · ${DateText.dayMonth(day.date)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    Text(
                      condition.description,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.temperature(day.temperatureMax),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  Text(
                    formatter.temperature(day.temperatureMin),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MiniStat(
                icon: Icons.water_drop_outlined,
                text: 'Lluvia ${formatter.percent(day.precipitationProbabilityMax)}',
              ),
              _MiniStat(
                icon: Icons.wb_sunny_outlined,
                text: 'UV máx. ${formatter.uv(day.uvIndexMax)}',
              ),
              _MiniStat(icon: Icons.air_rounded, text: formatter.wind(day.windSpeedMax)),
              if (window != null)
                CategoryChip(category: window.category, dense: true),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? _HourlyDetail(
                    day: day,
                    weather: weather,
                    formatter: formatter,
                    recommendation: recommendation,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _HourlyDetail extends StatelessWidget {
  const _HourlyDetail({
    required this.day,
    required this.weather,
    required this.formatter,
    required this.recommendation,
  });

  final DailyWeather day;
  final WeatherForecast weather;
  final UnitFormatter formatter;
  final DayRecommendation? recommendation;

  @override
  Widget build(BuildContext context) {
    final hours = weather.hoursOfDay(day.date);
    final scoreByTime = <DateTime, HourRecommendation>{
      for (final rec in recommendation?.hours ?? const <HourRecommendation>[])
        rec.time: rec,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 10),
        Text(
          'Por horas',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hours.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final hour = hours[index];
              final condition = WeatherCondition.fromCode(hour.weatherCode);
              final rec = scoreByTime[hour.time];
              return Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateText.hour(hour.time),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Icon(condition.icon, size: 22, color: AppColors.forest),
                    Text(
                      formatter.temperature(hour.temperature),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatter.percent(hour.precipitationProbability),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (rec != null)
                      Container(
                        width: 26,
                        height: 6,
                        decoration: BoxDecoration(
                          color: rec.category.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'La barra de color indica qué tan favorable es cada hora para la actividad seleccionada.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              context.read<WeatherProvider>().selectDate(day.date);
              context.read<NavigationProvider>().goTo(NavigationProvider.recommendations);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Ver recomendaciones de este día'),
          ),
        ),
      ],
    );
  }
}
