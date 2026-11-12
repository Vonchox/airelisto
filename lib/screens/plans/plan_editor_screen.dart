import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_text.dart';
import '../../models/activity_type.dart';
import '../../models/geo_location.dart';
import '../../models/place.dart';
import '../../models/planned_activity.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/planner_provider.dart';
import '../../providers/places_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/weather_provider.dart';
import '../../widgets/activity_selector.dart';
import '../../widgets/app_card.dart';
import '../../widgets/score_badge.dart';

/// Crea o edita una actividad planificada.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, this.plan, this.initialPlace});

  /// Plan existente que se está editando (`null` para crear uno nuevo).
  final PlannedActivity? plan;

  /// Lugar preseleccionado (por ejemplo, desde el detalle de un lugar).
  final OutdoorPlace? initialPlace;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PickResult {
  const _PickResult(this.place);

  final OutdoorPlace? place;
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late ActivityType _activity;
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _notes;
  String? _placeName;
  double? _placeLatitude;
  double? _placeLongitude;
  String? _error;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    if (plan != null) {
      _activity = plan.activity;
      _date = DateTime(plan.dateTime.year, plan.dateTime.month, plan.dateTime.day);
      _time = TimeOfDay(hour: plan.dateTime.hour, minute: plan.dateTime.minute);
      _placeName = plan.placeName;
      _placeLatitude = plan.placeLatitude;
      _placeLongitude = plan.placeLongitude;
      _notes = TextEditingController(text: plan.notes ?? '');
    } else {
      _activity = context.read<SettingsProvider>().activity;
      final suggestion = DateTime.now().add(const Duration(hours: 1));
      _date = DateTime(suggestion.year, suggestion.month, suggestion.day);
      _time = TimeOfDay(hour: suggestion.hour, minute: 0);
      final place = widget.initialPlace;
      if (place != null) {
        _placeName = place.displayName;
        _placeLatitude = place.latitude;
        _placeLongitude = place.longitude;
      }
      _notes = TextEditingController();
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  DateTime get _dateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = _date.isBefore(today) ? _date : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Fecha de la actividad',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Hora de la actividad',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _pickPlace() async {
    final favorites = context.read<FavoritesProvider>().places;
    final explored = context.read<PlacesProvider>().places.map((r) => r.place);
    final options = <OutdoorPlace>[];
    final seen = <String>{};
    for (final place in [...favorites, ...explored]) {
      if (seen.add(place.id)) options.add(place);
    }

    final result = await showModalBottomSheet<_PickResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: const Text('Sin lugar específico'),
                onTap: () => Navigator.of(sheetContext).pop(const _PickResult(null)),
              ),
              if (options.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Guarda lugares en favoritos o explora lugares cercanos para poder elegirlos aquí.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              for (final place in options)
                ListTile(
                  leading: const Icon(Icons.place_rounded, color: AppColors.forest),
                  title: Text(place.displayName),
                  subtitle: Text(place.kind.label),
                  onTap: () => Navigator.of(sheetContext).pop(_PickResult(place)),
                ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      final place = result.place;
      _placeName = place?.displayName;
      _placeLatitude = place?.latitude;
      _placeLongitude = place?.longitude;
    });
  }

  Future<void> _save() async {
    final planner = context.read<PlannerProvider>();
    final locationProvider = context.read<LocationProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final when = _dateTime;
    if (!_isEditing && when.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      setState(() => _error = 'Elige una fecha y hora que todavía no hayan pasado.');
      return;
    }

    final existing = widget.plan;
    final location = locationProvider.current ?? GeoLocation.demo;
    final notes = _notes.text.trim();

    final plan = PlannedActivity(
      id: existing?.id ?? planner.newId(),
      activity: _activity,
      dateTime: when,
      locationName: existing?.locationName ?? location.name,
      latitude: existing?.latitude ?? location.latitude,
      longitude: existing?.longitude ?? location.longitude,
      placeName: _placeName,
      placeLatitude: _placeLatitude,
      placeLongitude: _placeLongitude,
      notes: notes.isEmpty ? null : notes,
    );

    await planner.save(plan);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Plan actualizado' : 'Plan guardado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar plan' : 'Nuevo plan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text('Actividad', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ActivitySelector(
            selected: _activity,
            onChanged: (value) => setState(() => _activity = value),
          ),
          const SizedBox(height: 20),
          const Text('Fecha y hora', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    '${DateText.capitalize(DateText.weekdayShort(_date))} ${_date.day} ${DateText.month(_date).substring(0, 3)}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('${DateText.two(_time.hour)}:${DateText.two(_time.minute)}'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.onWarningSoft)),
          ],
          const SizedBox(height: 12),
          _ForecastHint(activity: _activity, dateTime: _dateTime, plan: widget.plan),
          const SizedBox(height: 20),
          const Text('Lugar', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            onTap: _pickPlace,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.place_rounded, color: AppColors.forest),
              title: Text(_placeName ?? 'Sin lugar específico'),
              subtitle: const Text('Toca para elegir entre favoritos y lugares cercanos'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Notas (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Por ejemplo: llevar agua y protector solar',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_isEditing ? 'Guardar cambios' : 'Guardar plan'),
          ),
        ],
      ),
    );
  }
}

/// Muestra la puntuación prevista para la fecha y hora elegidas, cuando están
/// dentro del pronóstico de la ubicación actual.
class _ForecastHint extends StatelessWidget {
  const _ForecastHint({
    required this.activity,
    required this.dateTime,
    required this.plan,
  });

  final ActivityType activity;
  final DateTime dateTime;
  final PlannedActivity? plan;

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final bundle = weather.bundle;
    if (bundle == null) return const SizedBox.shrink();

    // Solo aplica si el plan es para la ubicación del pronóstico cargado.
    if (plan != null) {
      final planLocation = GeoLocation(
        name: plan!.locationName,
        latitude: plan!.latitude,
        longitude: plan!.longitude,
      );
      if (planLocation.cacheKey != bundle.location.cacheKey) {
        return const SizedBox.shrink();
      }
    }

    final wall = DateTime.utc(dateTime.year, dateTime.month, dateTime.day, dateTime.hour);
    final hour = bundle.weather.hourAt(wall);
    if (hour == null) {
      return const Text(
        'Todavía no hay pronóstico para esa fecha (solo se consultan 5 días).',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    final daily = bundle.weather.dailyFor(wall);
    final result = weather.engine.evaluateHour(
      activity: activity,
      hour: hour,
      usAqi: bundle.airQuality?.hourAt(wall)?.usAqi,
      sunrise: daily?.sunrise,
      sunset: daily?.sunset,
    );
    if (result == null) {
      return const Text(
        'No hay datos suficientes para estimar las condiciones de esa hora.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    return AppCard(
      color: AppColors.mint,
      child: Row(
        children: [
          ScoreBadge(score: result.score, category: result.category, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Condiciones previstas: ${result.category.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(result.summary, style: const TextStyle(fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
