# RutaLibre 🚴

**Pedalea sin límites. Descubre Colombia sobre dos ruedas.**

RutaLibre es una plataforma de código abierto diseñada para ciclistas colombianos que quieren explorar el país de forma inteligente, segura y en comunidad. Desde rutas optimizadas para tu bicicleta hasta el seguimiento de tus actividades, RutaLibre es tu compañero de ruta definitivo.

---

## ¿Qué puedes hacer con RutaLibre?

- **Mapa interactivo** — Visualiza rutas ciclistas optimizadas para bicicleta en tiempo real, con capas y puntos de interés pensados para ciclistas.
- **Calculador de rutas** — Encuentra el camino más eficiente entre dos puntos, evitando vías de alto tráfico y priorizando ciclovías.
- **Grabación de actividades** — Registra tus salidas con GPS, consulta tu historial y revive cada recorrido.
- **Estadísticas** — Analiza tu progreso: distancia acumulada, desnivel, velocidad promedio y mucho más.
- **Comunidad** — Descubre y comparte rutas con otros ciclistas. Publica tus recorridos favoritos y explora los de la comunidad.
- **Retos** — Participa en desafíos colectivos, sube en el ranking y mantén la motivación pedaleando.
- **Puntos de interés (POIs)** — Encuentra cicloparqueaderos, talleres, tiendas y puntos de hidratación cerca de ti.
- **Alertas** — Recibe notificaciones sobre condiciones en tus rutas habituales.
- **Contribuciones** — Ayuda a mejorar el mapa reportando datos y verificando información de tu ciudad.

---

## Tecnologías

| Capa | Tecnología |
|------|-----------|
| App móvil | Flutter 3.16+ (iOS & Android) |
| Estado | Riverpod + Provider |
| Mapas | flutter_map |
| Autenticación | OAuth 2.0 (AppAuth) |
| Notificaciones | Firebase Cloud Messaging |
| Almacenamiento local | Hive + SharedPreferences |
| Navegación | GoRouter |

---

## Instalación

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.16
- Dart >= 3.2
- Xcode (para iOS) / Android Studio (para Android)

### Pasos

```bash
# Clona el repositorio
git clone https://github.com/JuanSebastianCondeFarias/rutaLibre.git
cd rutaLibre

# Instala las dependencias
flutter pub get

# Ejecuta la app
flutter run
```

> **Nota:** Para habilitar las notificaciones push necesitas configurar Firebase. Añade tu archivo `google-services.json` (Android) o `GoogleService-Info.plist` (iOS) en las rutas correspondientes. Estos archivos están excluidos del repositorio por seguridad.

---

## Contribuir

RutaLibre es un proyecto comunitario y toda ayuda es bienvenida:

1. Haz un fork del repositorio
2. Crea una rama para tu feature: `git checkout -b feature/mi-mejora`
3. Haz commit de tus cambios: `git commit -m 'feat: descripción de la mejora'`
4. Abre un Pull Request

Si encuentras un bug o tienes una idea, abre un [issue](https://github.com/JuanSebastianCondeFarias/rutaLibre/issues).

---

## Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

<p align="center">Hecho con amor por y para los ciclistas de Colombia 🇨🇴</p>
