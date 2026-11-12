import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_text.dart';
import '../../models/activity_type.dart';
import '../../models/recommendation.dart';
import '../../providers/load_status.dart';
import '../../providers/settings_provider.dart';
import '../../providers/weather_provider.dart';
import '../../widgets/activity_selector.dart';
import '../../widgets/app_card.dart';
import '../../widgets/hour_recommendation_tile.dart';
import '../../widgets/location_header.dart';
import '../../widgets/score_badge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_extensions.dart';

enum _SortMode { chronological, score }

/// Lista de horarios del día con su puntuación y la explicación de cada uno.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  _SortMode _sort = _SortMode.chronological;

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final settings = context.watch<SettingsProvider>();
    final bundle = weather.bundle;

    return Scaffold(
      appBar: AppBar(title: const Text('Recomendaciones')),
      body: SafeArea(
        child: bundle == null
            ? (weather.status == LoadStatus.error
                ? ErrorView(
                    message: weather.errorMessage ?? 'Inténtalo de nuevo.',
                    onRetry: () => weather.refresh(force: true),
                  )
                : const LoadingView(message: 'Consultando el pronóstico…'))
            : _buildContent(context, weather, settings),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WeatherProvider weather,
    SettingsProvider settings,
  ) {
    final bundle = weather.bundle!;
    final today = weather.todayAtLocation;
    final selectedDate = weather.selectedDate ?? bundle.weather.daily.first.date;
    final isToday = today != null && DateText.isSameDay(selectedDate, today);

    final notBefore = isToday && weather.nowAtLocation != null
        ? DateTime.utc(
            weather.nowAtLocation!.year,
            weather.nowAtLocation!.month,
            weather.nowAtLocation!.day,
            weather.nowAtLocation!.hour,
          )
        : null;
    final recommendation = weather.recommendationFor(
      settings.activity,
      selectedDate,
      notBefore: notBefore,
    );

    final hours = [...?recommendation?.hours];
    if (_sort == _SortMode.score) {
      hours.sort((a, b) => b.score.compareTo(a.score));
    }

    return RefreshIndicator(
      onRefresh: () => weather.refresh(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Align(alignment: Alignment.centerLeft, child: LocationChip()),
          const SizedBox(height: 12),
          ActivitySelector(
            selected: settings.activity,
            onChanged: settings.setActivity,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bundle.weather.daily.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = bundle.weather.daily[index];
                final label = today == null
                    ? DateText.capitalize(DateText.weekdayShort(day.date))
                    : '${DateText.relativeDay(day.date, today)} ${day.date.day}';
                return ChoiceChip(
                  label: Text(label),
                  selected: DateText.isSameDay(day.date, selectedDate),
                  onSelected: (_) => weather.selectDate(day.date),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (bundle.airQualityError != null) ...[
            InfoBanner.caution(
              message:
                  'Sin datos de calidad del aire: ${bundle.airQualityError} Las puntuaciones se calculan sin ese factor.',
            ),
            const SizedBox(height: 12),
          ],
          _DaySummary(
            recommendation: recommendation,
            date: selectedDate,
            activity: settings.activity,
            isToday: isToday,
          ),
          const SizedBox(height: 20),
          if (hours.isNotEmpty) ...[
            SectionHeader(
              title: 'Horarios',
              trailing: SegmentedButton<_SortMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: _SortMode.chronological, label: Text('Hora')),
                  ButtonSegment(value: _SortMode.score, label: Text('Mejor')),
                ],
                selected: {_sort},
                onSelectionChanged: (values) => setState(() => _sort = values.first),
              ),
            ),
            const SizedBox(height: 12),
            for (final hour in hours)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HourRecommendationTile(
                  key: ValueKey('${selectedDate.millisecondsSinceEpoch}-${hour.time.hour}-${settings.activity.id}'),
                  recommendation: hour,
                  formatter: settings.formatter,
                  highlight: recommendation?.bestHour?.time == hour.time,
                ),
              ),
          ],
          const SizedBox(height: 12),
          _AlgorithmCard(activity: settings.activity),
        ],
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.recommendation,
    required this.date,
    required this.activity,
    required this.isToday,
  });

  final DayRecommendation? recommendation;
  final DateTime date;
  final ActivityType activity;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    final window = rec?.bestWindow;

    if (rec == null || rec.isEmpty || window == null) {
      return AppCard(
        child: Text(
          isToday
              ? 'Ya no quedan horas útiles hoy para ${activity.verb}. Elige otro día para ver recomendaciones.'
              : 'No hay datos suficientes para evaluar este día.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateText.fullDate(date)} · ${activity.label}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ScoreBadge(score: window.averageScore, category: window.category, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mejor franja',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    Text(
                      DateText.hourRange(window.start, window.end),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    CategoryChip(category: window.category, dense: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(rec.bestHour!.summary, style: const TextStyle(height: 1.4)),
          if (rec.averageScore != null) ...[
            const SizedBox(height: 8),
            Text(
              'Puntuación media del día: ${rec.averageScore}/100',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Explica cómo funciona el algoritmo y los pesos de la actividad elegida.
class _AlgorithmCard extends StatelessWidget {
  const _AlgorithmCard({required this.activity});

  final ActivityType activity;

  @override
  Widget build(BuildContext context) {
    final config = context.read<WeatherProvider>().engine.config;
    final profile = config.profileFor(activity);
    final factors = ScoreFactor.values.toList()
      ..sort((a, b) => profile.weightOf(b).compareTo(profile.weightOf(a)));

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.info_outline_rounded, color: AppColors.forest),
          title: const Text(
            '¿Cómo se calcula la puntuación?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cada hora recibe una nota de 0 a 100 que combina cinco factores. Cada factor se convierte en una subnota (100 = condiciones ideales) y se promedia con estos pesos para ${activity.verb}:',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 10),
            for (final factor in factors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(factor.icon, size: 18, color: AppColors.forest),
                    const SizedBox(width: 8),
                    Expanded(child: Text(factor.label)),
                    Text(
                      '${(profile.weightOf(factor) * 100).round()} %',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'Después se restan ${config.nightPenalty} puntos si es de noche y se aplican topes cuando hay condiciones extremas (lluvia muy probable, aire dañino, calor o frío extremos, viento fuerte en bicicleta). '
              'Categorías: ${config.excellentMin}–100 Excelente, ${config.goodMin}–${config.excellentMin - 1} Bueno, ${config.cautionMin}–${config.goodMin - 1} Precaución y 0–${config.cautionMin - 1} Poco recomendable.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'Es una orientación basada en pronósticos: no garantiza seguridad ni reemplaza tu criterio o el consejo médico. Si falta un dato, su peso se reparte entre los demás factores.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
