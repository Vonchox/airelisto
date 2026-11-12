# AireListo

Aplicación Flutter que ayuda a decidir **cuándo y dónde conviene caminar, correr o
andar en bicicleta al aire libre**, combinando clima, calidad del aire, ubicación y
lugares cercanos de OpenStreetMap.

> Proyecto académico. La puntuación es una **orientación basada en datos públicos**;
> no es una garantía de seguridad ni un consejo médico. Ante condiciones extremas,
> síntomas o dudas de salud, decide con criterio propio y consulta a un profesional.

---

## Objetivo

Dar una respuesta clara a la pregunta *«¿es buen momento para salir?»*:

* una puntuación de **0 a 100** por actividad y por hora,
* las **mejores franjas** del día (ventanas de 2 horas),
* el **motivo** de cada resultado (temperatura, lluvia, UV, viento, aire),
* **lugares cercanos** donde practicar la actividad,
* un **planificador** local con favoritos.

## Funciones principales

| Pantalla | Qué hace |
|---|---|
| **Inicio** | Clima actual, selector de actividad, puntuación del momento y mejor franja de hoy, atajos a pronóstico y calidad del aire. |
| **Horarios** (Recomendaciones) | Mejores franjas del día elegido, detalle por hora y desglose de cada factor. |
| **Explorar** | Mapa (flutter_map + OpenStreetMap) y lista de lugares cercanos para la actividad, con filtros y radio de 2, 5 o 10 km. |
| **Mis planes** | Crear, editar y eliminar planes; favoritos de ubicaciones y lugares. |
| **Perfil** | Unidades (métrico / imperial), ubicación, acerca de los datos y atribuciones. |

Además:

* **Ubicación**: GPS con solicitud de permisos, búsqueda de ciudades y, solo como
  último recurso, una ubicación de demostración (Quito) claramente indicada.
* **Pronóstico de 5 días** con detalle por hora y selección de día.
* **Calidad del aire** (PM2.5, PM10 y un único índice: US AQI).
* **Actualización manual**, hora de la última actualización y caché.
* **Manejo de errores**: sin conexión, error del servidor, límite de solicitudes,
  JSON inválido, permiso denegado, GPS apagado, búsqueda vacía y datos incompletos.

## Tecnologías

* Flutter / Dart, Material 3, localización en español.
* `provider` (estado), `shared_preferences` (favoritos, planes, ajustes).
* `http` (consumo de APIs), `geolocator` (GPS), `flutter_map` + `latlong2` (mapa),
  `url_launcher` (enlaces).
* Sin claves de API ni servicios de pago.

## APIs utilizadas

| API | Uso | Documentación |
|---|---|---|
| Open-Meteo Forecast `api.open-meteo.com/v1/forecast` | Clima actual, por hora y diario (5 días, `timezone=auto`). | <https://open-meteo.com/en/docs> |
| Open-Meteo Air Quality `air-quality-api.open-meteo.com/v1/air-quality` | PM2.5, PM10 y `us_aqi`. | <https://open-meteo.com/en/docs/air-quality-api> |
| Open-Meteo Geocoding `geocoding-api.open-meteo.com/v1/search` | Búsqueda de ciudades. | <https://open-meteo.com/en/docs/geocoding-api> |
| Overpass API (OpenStreetMap) | Parques, ciclovías, rutas, pistas… cercanos. | <https://wiki.openstreetmap.org/wiki/Overpass_API> |

Los datos de clima y calidad del aire son modelados (no mediciones de una estación
concreta) y pueden diferir de la realidad local.

## Arquitectura

Capas con dependencias en un solo sentido: `screens → providers → services/logic → models`.

```
lib/
├── main.dart, app.dart          Arranque, MultiProvider, tema y localización
├── core/
│   ├── constants/               Hosts, tiempos, colores, rutas de imágenes
│   ├── errors/                  AppException y subclases (mensajes en español)
│   ├── theme/                   Tema Material 3
│   └── utils/                   JSON, fechas, unidades, distancias, enlaces
├── models/                      Datos inmutables con fromJson/toJson defensivos
├── logic/
│   ├── scoring_config.dart      Pesos, curvas y límites (configuración central)
│   ├── recommendation_engine.dart  Puntuación por hora y ventanas del día
│   ├── place_classifier.dart    Clasificación de etiquetas OSM y compatibilidad
│   └── place_ranker.dart        Filtrado, deduplicado y orden de lugares
├── services/                    ApiClient, Weather/AirQuality/Geocoding/Overpass,
│                                WeatherRepository (caché), Location, Storage
├── providers/                   Estado: ubicación, clima, lugares, planes, favoritos…
├── widgets/                     Componentes reutilizables
└── screens/                     Una carpeta por pantalla
test/                            Pruebas unitarias (ver más abajo)
assets/                          Imágenes opcionales (ver assets/README.md)
```

Decisiones de diseño relevantes:

* **Fallos aislados.** Si falla la calidad del aire se sigue mostrando el pronóstico
  (con aviso); Overpass es independiente del clima.
* **Zonas horarias.** Open-Meteo entrega horas locales del lugar consultado. Se
  interpretan como «hora de pared» (sin convertir con la zona del teléfono), de modo
  que el resultado es el mismo sin importar dónde esté el dispositivo.
* **Caché.** Pronóstico: 15 min en memoria, con unificación de solicitudes
  simultáneas; lugares: 30 min. «Actualizar» fuerza una nueva consulta.
* **Escala única de aire.** Solo US AQI, sin mezclar índices. Para PM se muestran
  como referencia las guías de la OMS 2021 (24 h: PM2.5 15 µg/m³, PM10 45 µg/m³).

## Algoritmo de puntuación (0–100)

Está en `lib/logic/` y **toda su configuración vive en `scoring_config.dart`**.

1. Cada factor se convierte en un valor de 0 a 100 con una curva lineal por tramos:
   temperatura aparente (rango ideal según la actividad), probabilidad y cantidad de
   lluvia, índice UV, viento y US AQI.
2. Se hace un **promedio ponderado** con pesos distintos por actividad:

   | Factor | Caminar | Correr | Bicicleta |
   |---|---|---|---|
   | Temperatura | 0,30 | 0,27 | 0,22 |
   | Lluvia | 0,27 | 0,22 | 0,26 |
   | UV | 0,18 | 0,14 | 0,11 |
   | Calidad del aire | 0,15 | 0,27 | 0,13 |
   | Viento | 0,10 | 0,10 | 0,28 |

   Rangos ideales de temperatura aparente: caminar 14–26 °C, correr 6–17 °C,
   bicicleta 12–25 °C.
3. Si falta algún dato, los **pesos se renormalizan** con los factores disponibles.
   Si se cubre menos del 50 % del peso, esa hora no se puntúa y se omite de las
   recomendaciones, en lugar de inventar un valor.
4. **Penalización nocturna** de 20 puntos fuera del horario diurno.
5. **Límites duros**: condiciones muy adversas limitan la puntuación máxima aunque
   el resto sea bueno (p. ej. US AQI ≥ 151 → máx. 39; US AQI ≥ 101 → máx. 59;
   viento ≥ 45 km/h en bicicleta → máx. 39; lluvia muy probable o intensa → máx. 39).
6. Se evalúan las horas de 05:00 a 21:00 y se buscan **ventanas de 2 horas**
   consecutivas.

| Puntos | Categoría |
|---|---|
| 80–100 | Excelente |
| 60–79 | Bueno |
| 40–59 | Precaución |
| 0–39 | Poco recomendable |

### «Explorar lugares»

Es independiente del clima. Los lugares se ordenan con
`0,7 × compatibilidad con la actividad + 0,3 × cercanía`. La app **no afirma** que un
lugar esté abierto, sea seguro o esté en buen estado: solo muestra lo que figura en
OpenStreetMap, que es colaborativo y puede estar incompleto o desactualizado.

## Requisitos y puesta en marcha

* Flutter estable reciente (Dart SDK ≥ 3.13; el `pubspec.yaml` declara el SDK del
  proyecto original) y un emulador o dispositivo Android / iOS.
* Conexión a internet para las APIs.

```bash
flutter pub get      # instala dependencias
flutter analyze      # análisis estático
flutter test         # pruebas unitarias
flutter run          # ejecuta la app en el dispositivo conectado
```

> Si tu versión de Flutter resuelve alguna dependencia con otra versión mayor,
> ajusta la restricción en `pubspec.yaml` y vuelve a ejecutar `flutter pub get`.

### Permisos

* **Android** (`android/app/src/main/AndroidManifest.xml`): `INTERNET`,
  `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`.
* **iOS** (`ios/Runner/Info.plist`): `NSLocationWhenInUseUsageDescription`.

Si rechazas el permiso o el GPS está apagado, puedes buscar una ciudad manualmente.

### Imágenes

La app no trae imágenes: muestra marcadores de posición. Para añadir las tuyas,
consulta **`assets/README.md`** (nombres de archivo, carpetas y tamaños sugeridos).

## Pruebas

```
test/
├── core/utils_test.dart                  Distancias, unidades y fechas
├── models/weather_forecast_test.dart     Parseo de JSON del clima
├── models/air_quality_test.dart          Parseo de JSON de aire y categorías US AQI
├── logic/recommendation_engine_test.dart Puntuación, categorías, límites, ventanas
├── logic/place_logic_test.dart           Clasificación y filtrado de lugares
├── services/api_services_test.dart       ApiClient y servicios con MockClient
├── services/weather_repository_test.dart Caché, TTL, refresco y fallos aislados
└── providers/storage_providers_test.dart Planes, favoritos y persistencia
```

Los servicios se prueban con `MockClient` (paquete `http/testing.dart`) y respuestas
que reproducen la estructura documentada; **las pruebas no usan la red**.

## Limitaciones

* La puntuación es una heurística propia; no considera condición física, edad,
  salud ni equipamiento de la persona.
* Los datos de OpenStreetMap y de los modelos meteorológicos pueden ser incompletos
  o imprecisos. Overpass es un servicio público y puede responder con lentitud o
  límite de uso; la app reintenta con una instancia alternativa.
* La ubicación obtenida por GPS se muestra como «Mi ubicación» (no hay geocodificación
  inversa).
* Los favoritos y planes se guardan solo en el dispositivo (sin cuenta ni sincronización).
* No hay notificaciones: los planes son recordatorios dentro de la app.

## Créditos y atribuciones

* Datos meteorológicos y de calidad del aire: [Open-Meteo](https://open-meteo.com)
  (licencia CC BY 4.0, uso no comercial gratuito).
* Mapas y lugares: © [colaboradores de OpenStreetMap](https://www.openstreetmap.org/copyright)
  (licencia ODbL). La atribución se muestra sobre el mapa.

