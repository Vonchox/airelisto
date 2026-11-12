# Recursos gráficos de AireListo

La aplicación **no incluye imágenes**. Cada lugar donde se usaría una imagen
muestra un marcador de posición (ver `lib/widgets/image_placeholder.dart`) y
**no falla si el archivo todavía no existe**. Cuando agregues un archivo con el
nombre indicado, aparecerá automáticamente (no hace falta tocar el código).

Las rutas están centralizadas en `lib/core/constants/app_assets.dart`.

## Dónde colocar cada archivo

| Archivo | Carpeta | Dónde se muestra | Tamaño sugerido |
|---|---|---|---|
| `logo.png` | `assets/images/` | Pantalla Perfil (cabecera) | 512 × 512 px, fondo transparente |
| `home_header.jpg` | `assets/images/` | Fondo de la tarjeta de clima en Inicio (se oscurece con un degradado) | 1200 × 800 px |
| `activity_walking.jpg` | `assets/images/` | Imagen de la actividad Caminar (reservada) | 800 × 600 px |
| `activity_running.jpg` | `assets/images/` | Imagen de la actividad Correr (reservada) | 800 × 600 px |
| `activity_cycling.jpg` | `assets/images/` | Imagen de la actividad Bicicleta (reservada) | 800 × 600 px |
| `place_default.jpg` | `assets/images/` | Cabecera del detalle de un lugar | 1000 × 600 px |
| `empty_plans.png` | `assets/images/` | Estado vacío de "Mis planes" | 600 × 400 px |
| `empty_favorites.png` | `assets/images/` | Estado vacío de Favoritos | 600 × 400 px |
| `empty_places.png` | `assets/images/` | Reservada para el estado vacío de Explorar | 600 × 400 px |

Los iconos sueltos (SVG/PNG) pueden ir en `assets/icons/`; la carpeta ya está
declarada en `pubspec.yaml`.

## Icono de la app y pantalla de inicio

Esos recursos no se manejan desde `assets/`:

* **Android:** reemplaza los `ic_launcher.png` de
  `android/app/src/main/res/mipmap-*/`.
* **iOS:** reemplaza las imágenes de
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

## Notas

* Si usas otro nombre o extensión, actualiza la constante correspondiente en
  `lib/core/constants/app_assets.dart`.
* Las carpetas contienen un archivo `.gitkeep` para que existan aunque estén
  vacías; Flutter exige que las carpetas declaradas en `pubspec.yaml` existan.
* Respeta la licencia de las imágenes que incorpores (y atribúyelas en la
  pantalla Perfil si la licencia lo exige).
