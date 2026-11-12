# AireListo

**Fuente para una presentación académica sobre el proyecto de software**  
**Tema:** planificación de actividades al aire libre con datos de clima, calidad del aire y lugares cercanos.  
**Versión declarada:** 1.0.0 (`1.0.0+1` en el manifiesto del proyecto).  
**Contexto:** proyecto académico basado en el taller de clase «Uso de APIs» (Alvarado), según el README.

## 1. Problema, objetivo y propuesta

Para decidir si conviene caminar, correr o salir en bicicleta, una persona puede necesitar consultar el pronóstico, la calidad del aire y un mapa por separado. Además, una misma condición puede afectar de manera diferente a cada actividad. Por ejemplo, el viento tiene más peso en la evaluación de ciclismo que en la de caminata.

AireListo reúne esos datos en una aplicación en español. El usuario selecciona una ubicación y una actividad. La app evalúa las horas del pronóstico, sugiere una franja, muestra los factores que explican el resultado y permite buscar lugares cercanos compatibles. El usuario puede guardar un plan y volver a sus favoritos desde el mismo dispositivo.

- **Pregunta que resuelve:** ¿Cuándo y dónde conviene realizar mi actividad al aire libre?
- **Público previsto:** personas que caminan, corren o andan en bicicleta de forma recreativa y quieren consultar las condiciones antes de salir.
- **Aporte del proyecto:** transformar datos de varias fuentes en recomendaciones por hora y por actividad, con criterios explícitos. La recomendación es orientativa y depende de los datos disponibles.
- **Dos resultados complementarios:** la puntuación de un horario depende de condiciones ambientales. El orden de los lugares depende de su compatibilidad registrada y de la distancia.

## 2. Recorrido por la aplicación

| Pantalla | Funciones principales |
|---|---|
| **Inicio** | Muestra ubicación, condiciones actuales y selector de actividad. Presenta la puntuación de la hora actual cuando hay datos suficientes y la mejor franja disponible. Si ya no quedan horas útiles del día, busca el primer día posterior con resultados. Incluye accesos a Pronóstico, Aire y Lugares. |
| **Horarios** | Permite elegir el día, ver la mejor hora y la franja recomendada, y ordenar las horas cronológicamente o por puntuación. Muestra el detalle de factores y las advertencias de cada hora. |
| **Explorar** | Muestra un mapa y una lista de lugares. Ofrece filtros según la actividad y radios de 2, 5 o 10 km. El detalle indica distancia, tipo y motivo de compatibilidad. Permite guardar el lugar como favorito, abrir su ficha en OpenStreetMap o iniciar un plan desde «Planificar aquí». |
| **Mis planes** | Muestra planes próximos y pasados. Permite crear, editar y eliminar planes con actividad, fecha y hora, lugar opcional y notas. El editor muestra una valoración si dispone de pronóstico aplicable. Desde aquí se accede a favoritos de ciudades y lugares. |
| **Perfil** | Permite cambiar ubicación, usar GPS, elegir unidades y modificar preferencias. Incluye información sobre las API y atribuciones. |
| **Pronóstico de 5 días** | Incluye el día actual, resúmenes diarios y detalle por horas. Desde el día seleccionado se puede abrir su recomendación. |
| **Calidad del aire** | Muestra US AQI, partículas PM2.5 y PM10, categorías del índice y una vista de las próximas 24 horas cuando hay datos. |
| **Elegir ubicación** | Permite buscar ciudades, elegir una ubicación favorita o solicitar el GPS. |

### Ubicación y preferencias

Al iniciar, la app recupera la última ubicación guardada. Si es una posición GPS, puede intentar actualizarla en segundo plano. Si aún no hay una ubicación guardada, intenta obtener la posición del dispositivo con permiso del usuario. Si ese intento falla, muestra **Quito, Pichincha, Ecuador** como ubicación de demostración, identificada en la interfaz. Quito es un valor de respaldo y la búsqueda permite elegir otras ciudades.

La búsqueda manual se activa a partir de dos caracteres y espera 450 ms después de la última pulsación. Los ajustes iniciales son **Caminar**, **sistema métrico** y **radio de 5 km**. Cambiar a imperial modifica la presentación de unidades. El motor sigue utilizando unidades métricas.

## 3. APIs, servicios externos e integraciones del dispositivo

El código consulta **cuatro APIs web de datos** y un **servicio de teselas cartográficas**. La ubicación del dispositivo también puede obtenerse mediante las APIs de ubicación de la plataforma, a través de `geolocator`.

### APIs y servicios web que consulta la aplicación

| Fuente | Consulta que implementa AireListo | Información utilizada |
|---|---|---|
| **Open-Meteo Forecast API** | `GET https://api.open-meteo.com/v1/forecast` con coordenadas, `timezone=auto` y `forecast_days=5`. | Temperatura, sensación térmica, humedad actual, probabilidad y cantidad de precipitación, viento, índice UV, códigos meteorológicos, amanecer y atardecer. |
| **Open-Meteo Air Quality API** | `GET https://air-quality-api.open-meteo.com/v1/air-quality` con coordenadas y datos actuales y horarios para cinco días. | US AQI, PM2.5 y PM10. El motor usa el US AQI de la hora correspondiente. |
| **Open-Meteo Geocoding API** | `GET https://geocoding-api.open-meteo.com/v1/search` con el nombre buscado, idioma español y hasta 10 coincidencias solicitadas. | Nombre, región, país y coordenadas de las ciudades encontradas. |
| **Overpass API** | `POST https://overpass-api.de/api/interpreter` con una consulta Overpass QL en el campo `data`. Ante ciertos fallos, prueba `https://overpass.kumi.systems/api/interpreter`, otra instancia de la misma API. | Etiquetas y coordenadas de parques, senderos, pistas, ciclovías, rutas y otros espacios candidatos, según el radio y la actividad. |
| **Servicio de teselas de OpenStreetMap** | `GET https://tile.openstreetmap.org/{z}/{x}/{y}.png` mediante `flutter_map`. El zoom y la zona visible determinan las teselas solicitadas. | Imágenes PNG que forman el fondo del mapa de Explorar. Los marcadores se generan con los lugares obtenidos vía Overpass. |

El código realiza estas consultas sin configurar claves de API. Clima y calidad del aire provienen de modelos y pueden diferir de las condiciones observadas en una calle o parque. La app mantiene las horas del pronóstico como horas locales de la ubicación consultada y usa el desplazamiento UTC recibido para calcular la hora actual en ese lugar.

### Integraciones de la plataforma

| Integración | Uso en AireListo |
|---|---|
| **Ubicación y permisos mediante `geolocator`** | Comprueba si el servicio de ubicación está activo, verifica o solicita permiso y obtiene latitud y longitud del dispositivo. Esas coordenadas pueden alimentar las consultas de clima, aire y lugares. |
| **Almacenamiento local mediante `shared_preferences`** | Lee y guarda la ubicación elegida, preferencias, planes y favoritos en el dispositivo. |
| **Apertura de enlaces mediante `url_launcher`** | Abre en el navegador la ficha de un lugar en OpenStreetMap, su sitio web si está registrado y las páginas de documentación o atribución. |

La lista de servicios web se verifica en `lib/core/constants/app_constants.dart`, `lib/services/` y la configuración de `TileLayer` en `lib/screens/explore/explore_screen.dart`. La obtención de coordenadas del dispositivo está en `lib/services/location_service.dart`.

### Cómo se interpreta la calidad del aire

| US AQI redondeado | Etiqueta mostrada |
|---:|---|
| 0–50 | Buena |
| 51–100 | Moderada |
| 101–150 | Dañina para grupos sensibles |
| 151–200 | Dañina |
| 201–300 | Muy dañina |
| 301 en adelante | Peligrosa |

El **US AQI** es el índice de calidad del aire. La **puntuación AireListo** es un resultado propio de 0 a 100 que combina cinco factores. Las partículas **PM2.5** y **PM10** se muestran en µg/m³. La pantalla presenta como referencia las guías OMS 2021 de **promedio de 24 horas**, con 15 µg/m³ para PM2.5 y 45 µg/m³ para PM10. Esas referencias corresponden a promedios de 24 horas, mientras que los valores de la pantalla pueden ser de una hora.

## 4. Algoritmo de recomendaciones

1. **Convertir los datos en subpuntuaciones de 0 a 100.** Se usa la sensación térmica y, si falta, la temperatura. La temperatura recibe 100 dentro del rango ideal y baja linealmente al alejarse. Lluvia, viento, UV y US AQI reciben 100 hasta el valor ideal máximo y bajan linealmente hasta cero en el límite configurado. Con ambos datos de precipitación, la subpuntuación de lluvia combina 60 % de probabilidad y 40 % de cantidad. Con un único dato de precipitación, usa la subpuntuación disponible completa.
2. **Calcular el promedio ponderado.** Se multiplica cada subpuntuación por su peso y se divide la suma entre el peso total disponible. Si los factores disponibles cubren menos del 50 % del peso original, la hora queda sin puntuar. Si hay cobertura suficiente, los factores disponibles se reponderan y se indica cuáles faltan.
3. **Restar 20 puntos si la hora queda completamente antes del amanecer o empieza a partir del atardecer**, según los datos disponibles de luz natural.
4. **Aplicar topes por condiciones adversas.** La puntuación se acota al intervalo 0–100, se redondea y se aplica el tope activo más bajo. Un tope limita el resultado máximo y conserva un resultado inferior si ya lo era.
5. **Mostrar la categoría y los motivos.** Se presentan factores, valores, observaciones y un resumen que destaca condiciones favorables o desfavorables.
6. **Elegir la mejor franja.** Se evalúan las horas de inicio de 05:00 a 21:00, inclusive. Se comparan las medias de parejas de horas consecutivas y se elige la mejor. Si faltan parejas consecutivas, se muestra la mejor hora individual como franja de una hora.

### Pesos según actividad

| Factor | Caminar | Correr | Bicicleta |
|---|---:|---:|---:|
| Temperatura | 30 % | 27 % | 22 % |
| Lluvia | 27 % | 22 % | 26 % |
| UV | 18 % | 14 % | 11 % |
| Calidad del aire | 15 % | 27 % | 13 % |
| Viento | 10 % | 10 % | 28 % |

| Puntos de AireListo | Categoría |
|---:|---|
| 80–100 | Excelente |
| 60–79 | Bueno |
| 40–59 | Precaución |
| 0–39 | Poco recomendable |

### Topes configurados

| Condición | Actividad | Máximo |
|---|---|---:|
| Probabilidad de precipitación ≥ 80 % o precipitación horaria ≥ 4 mm | Todas | 39 |
| US AQI ≥ 151 | Todas | 39 |
| US AQI ≥ 101 | Todas | 59 |
| Sensación térmica ≥ 36 °C o ≤ −5 °C | Todas | 39 |
| Índice UV ≥ 11 | Todas | 59 |
| Sensación térmica ≥ 32 °C | Correr | 59 |
| Viento ≥ 45 km/h | Bicicleta | 39 |
| Viento ≥ 35 km/h | Bicicleta | 59 |

### Ejemplo calculado para explicar en una diapositiva

**Escenario hipotético de una hora diurna:** sensación térmica de 22 °C, probabilidad de lluvia de 20 %, precipitación de 0,4 mm, índice UV de 4, US AQI de 60 y viento de 45 km/h. Hay datos para los cinco factores.

| Resultado | Caminar | Bicicleta |
|---|---:|---:|
| Subpuntuación de temperatura | 100 | 100 |
| Subpuntuación de lluvia | 84,67 | 80 |
| Subpuntuación de UV | 87,50 | 87,50 |
| Subpuntuación de aire | 95 | 92,31 |
| Subpuntuación de viento | 37,50 | 0 |
| Promedio ponderado aproximado | 86,61 | 64,43 |
| Resultado final | **87 · Excelente** | **39 · Poco recomendable** |

En bicicleta, el viento tiene un peso de 28 % y 45 km/h activa el tope de 39. Para caminar, el viento pesa 10 % y ese tope específico de ciclismo no se aplica. Los datos del ejemplo son ilustrativos y la categoría representa la salida de la heurística.

## 5. Búsqueda y orden de lugares

Overpass devuelve candidatos alrededor de la ubicación seleccionada. La consulta utiliza etiquetas acordes a la actividad. Para caminar, incluye parques, jardines, reservas y senderos. Para correr, incluye parques, pistas y rutas peatonales. Para bicicleta, incluye ciclovías con nombre, rutas ciclistas, pistas y caminos registrados para bicicletas.

1. `PlaceClassifier` interpreta etiquetas de tipo, actividad y acceso. Descarta compatibilidad cuando se indica acceso `private` o `no`, y aplica restricciones como `bicycle=no` para ciclismo o `foot=no` para caminar y correr.
2. `PlaceRanker` aplica los filtros. Omite tramos lineales sin nombre y agrupa los de igual tipo y nombre, conservando el candidato más cercano. La lista final se limita a 60 resultados.
3. **Orden = 0,7 × compatibilidad + 0,3 × cercanía.** La cercanía va de 1 en el centro a 0 en el borde del radio. La distancia es geográfica en línea recta. En empate se prioriza la menor distancia.
4. La ficha explica el motivo usando las etiquetas disponibles. La información sobre acceso, iluminación u otras características depende de lo registrado en OpenStreetMap.

## 6. Arquitectura y tecnologías

**Diagrama propuesto para la presentación:** `Pantallas y widgets → Proveedores de estado → Servicios y motor de reglas → Modelos de datos`. Dibujar un ramal de los servicios hacia las fuentes externas y otro hacia el almacenamiento local.

| Componente | Implementación y responsabilidad |
|---|---|
| **Interfaz** | Flutter y Dart. Material 3, textos en español, navegación por cinco pestañas y componentes reutilizables para estados, tarjetas, factores e insignias. |
| **Estado** | `provider`, `ChangeNotifier` y `MultiProvider` para ubicación, clima, lugares, preferencias, favoritos, planes y navegación. |
| **Red y datos** | `http` y un `ApiClient` común. Servicios separados para pronóstico, aire, ciudades y Overpass. Los modelos interpretan JSON y toleran campos opcionales o registros incompletos. |
| **Lógica** | `ScoringConfig` define reglas y pesos. `RecommendationEngine` evalúa horas y franjas. `PlaceClassifier` y `PlaceRanker` interpretan etiquetas y ordenan lugares. |
| **GPS, mapa y enlaces** | `geolocator` para posición y permisos, `flutter_map` y `latlong2` para el mapa, `url_launcher` para enlaces. |
| **Persistencia** | `shared_preferences` guarda en el dispositivo la última ubicación, unidades, actividad, radio, favoritos y planes. |

### Rendimiento y respuesta ante fallos

- **Clima y aire:** se solicitan en paralelo. La caché dura 15 minutos en memoria. Las solicitudes simultáneas para una misma ubicación se comparten. Si falla aire, se conserva el pronóstico y se avisa al usuario. Si falla una actualización posterior de clima, se pueden seguir mostrando los últimos datos válidos de la ubicación activa con su hora de actualización.
- **Lugares:** se consultan al entrar a Explorar. La caché dura 30 minutos en memoria y distingue ubicación, actividad y radio. La búsqueda de lugares opera de forma independiente al pronóstico.
- **Actualización manual:** evita reutilizar una entrada de caché vigente. La app maneja falta de conexión, tiempos de espera, respuestas inválidas, saturación y límite de solicitudes.
- **GPS:** Android declara acceso a internet y ubicación aproximada y precisa. iOS declara una descripción de uso de ubicación mientras se usa la app. La búsqueda manual es una alternativa si el GPS está apagado o se deniega el permiso.

## 7. Pruebas y estado de verificación

El repositorio contiene **115 pruebas unitarias declaradas en ocho archivos Dart**. Los servicios se prueban con `MockClient` y respuestas simuladas, sin consultar la red.

| Área | Casos revisados en el código de pruebas |
|---|---|
| Motor de recomendaciones | Pesos, curvas, categorías, lluvia intensa, viento en ciclismo, US AQI, calor, noche, cobertura de datos y ventanas consecutivas. |
| Lugares | Clasificación por etiquetas, acceso, compatibilidad, filtros y orden. |
| Servicios y repositorio | Construcción de consultas, manejo de errores, parseo, caché, actualización forzada y fallo aislado de calidad del aire. |
| Modelos, estado y utilidades | JSON de clima y aire, persistencia de planes y favoritos, distancias, unidades y fechas. |

La revisión para esta fuente fue estática. El manifiesto requiere Dart `^3.13.7` y el SDK local identificado es `3.13.5`. La ejecución de pruebas y el comportamiento en un dispositivo quedan pendientes de verificación con un SDK compatible. Para una demostración, preparar el proyecto con `flutter pub get`, revisar con `flutter analyze` y `flutter test`, y ejecutar con `flutter run` en el dispositivo o emulador elegido.

## 8. Alcance y limitaciones

- La puntuación es una heurística académica basada en pronósticos. Factores personales como edad, salud, condición física y equipamiento quedan fuera del modelo.
- El pronóstico y la cartografía dependen de servicios externos. Los modelos pueden diferir de la situación local y las etiquetas de OpenStreetMap pueden estar incompletas o desactualizadas. El estado actual, el horario de apertura y la seguridad de un lugar requieren verificación aparte.
- El GPS identifica la posición como «Mi ubicación». La aplicación carece de geocodificación inversa.
- Los planes y favoritos se almacenan localmente. El alcance implementado excluye cuentas, sincronización y notificaciones.
- Los recursos gráficos opcionales de la interfaz se documentan en `assets/README.md`. El proyecto utiliza marcadores de posición cuando esos recursos faltan.

## 9. Guion sugerido para 12 diapositivas

| N.º | Diapositiva | Mensaje para explicar | Recurso visual sugerido |
|---:|---|---|---|
| 1 | AireListo | Aplicación académica para elegir cuándo y dónde salir a caminar, correr o ir en bicicleta. | Título, nombres del equipo y materia si se proporcionan, imagen de fondo discreta. |
| 2 | El problema | Decidir una salida requiere combinar condiciones ambientales, actividad y lugares disponibles. | Pregunta central y tres iconos de clima, aire y mapa. |
| 3 | Recorrido del usuario | Elegir ubicación y actividad → consultar una franja → explorar lugares → guardar un plan. | Flujo de cuatro pasos. |
| 4 | Pantallas principales | Mostrar Inicio, Horarios, Explorar, Mis planes y Perfil. Mencionar los detalles de pronóstico y aire. | Capturas reales si están adjuntas o esquema rotulado. |
| 5 | APIs y servicios de datos | Presentar las tres APIs de Open-Meteo, Overpass y el servidor de teselas de OpenStreetMap. Indicar que la ubicación puede venir de Geocoding o del dispositivo mediante `geolocator`. | Diagrama con las fuentes, el dato que aporta cada una y la pantalla donde se utiliza. |
| 6 | Cómo se puntúa una hora | Subpuntuaciones → pesos por actividad → cobertura y ajustes → categoría y motivos. | Flujo con barras de pesos. |
| 7 | La misma hora, dos resultados | En el escenario hipotético de viento a 45 km/h, caminar obtiene 87 y bicicleta obtiene 39. Explicar el tope de ciclismo. | Dos barras de 0 a 100 con el tope señalado. |
| 8 | Mejor hora y mejor franja | La app compara pares consecutivos de horas y presenta una franja de dos horas cuando puede construirla. | Línea de tiempo ilustrativa rotulada. |
| 9 | Dónde practicar y cómo planificar | El orden de lugares combina compatibilidad y cercanía. Desde un lugar se puede crear un plan. | Mapa esquemático y fórmula 70 % / 30 %. |
| 10 | Arquitectura y manejo de errores | Estado, servicios, lógica y persistencia local. La app puede mostrar clima aunque falle el servicio de aire. | Diagrama de capas y ramales. |
| 11 | Pruebas y límites | Explicar el alcance de las pruebas escritas y las dependencias de los pronósticos y la cartografía. | Tabla breve de pruebas y dos límites. |
| 12 | Demostración y cierre | Buscar Quito, comparar dos actividades en el mismo día, abrir una recomendación, explorar un lugar y guardar un plan. | Capturas reales o lista corta del recorrido. |

## 10. Instrucción para copiar en NotebookLM

> Genera una presentación académica en español sobre AireListo basada en este Markdown. Usa el guion de 12 diapositivas y redacta títulos claros con dos a cuatro ideas breves por diapositiva. Si el formato admite notas del presentador, lleva allí el detalle técnico y el relato de la demostración. Usa diagramas para el recorrido, la arquitectura y la evaluación horaria. En el caso numérico, indica «Ejemplo hipotético» y conserva 87 para caminar y 39 para bicicleta. Diferencia visualmente el US AQI de la puntuación AireListo. Usa una paleta de fondo claro con verde `#245C4F`, menta `#E6F2EC`, azul `#69A9D0` y ámbar `#F2C14E`. Si se adjuntan capturas reales, úsalas para las pantallas. Si faltan, utiliza esquemas identificados como ilustrativos. Incluye las atribuciones de Open-Meteo y OpenStreetMap. Omite autores, institución, resultados de pruebas ejecutadas y métricas de uso cuando no se hayan proporcionado.

## 11. Referencias dentro del proyecto

- **Alcance, puesta en marcha y créditos:** `README.md`, `pubspec.yaml`, `assets/README.md`.
- **Pesos, umbrales, categorías y franjas:** `lib/logic/scoring_config.dart`, `lib/logic/recommendation_engine.dart`, `lib/models/recommendation.dart`.
- **Datos, caché y errores:** `lib/services/`, `lib/providers/weather_provider.dart`, `lib/providers/location_provider.dart`, `lib/core/constants/app_constants.dart`.
- **Mapa y clasificación:** `lib/screens/explore/`, `lib/logic/place_classifier.dart`, `lib/logic/place_ranker.dart`, `lib/providers/places_provider.dart`.
- **Pruebas:** `test/core/`, `test/models/`, `test/logic/`, `test/services/` y `test/providers/`.
- **Créditos de datos:** Open-Meteo para clima, aire y geocodificación. © colaboradores de OpenStreetMap para cartografía y lugares consultados mediante Overpass.

### Anexo técnico. Curvas por actividad

Cada celda de temperatura indica el intervalo que da 100 y los dos extremos que dan 0. Las otras celdas muestran el máximo que todavía da 100 seguido del valor a partir del cual la subpuntuación es 0. Entre esos puntos se interpola linealmente.

| Variable | Caminar | Correr | Bicicleta |
|---|---|---|---|
| Sensación térmica | Ideal 14–26 °C, cero a 0 y 38 °C | Ideal 6–17 °C, cero a −5 y 33 °C | Ideal 12–25 °C, cero a 0 y 36 °C |
| Probabilidad de lluvia | 10 % → 70 % | 10 % → 65 % | 10 % → 60 % |
| Precipitación por hora | 0 → 3 mm | 0 → 2,5 mm | 0 → 2 mm |
| Viento | 20 → 60 km/h | 15 → 50 km/h | 10 → 40 km/h |
| Índice UV | 3 → 11 | 3 → 11 | 3 → 11 |
| US AQI | 50 → 250 | 50 → 150 | 50 → 180 |
