// apps/mobile/lib/core/services/geocoding_service.dart
// Geocodificación en cascada: Geoapify → Photon → Nominatim

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado de búsqueda de dirección.
class ResultadoBusqueda {
  final double lat;
  final double lon;
  final String nombre;
  final String detalle;

  const ResultadoBusqueda({
    required this.lat,
    required this.lon,
    required this.nombre,
    required this.detalle,
  });
}

/// Servicio de geocodificación con cascada de proveedores.
/// Prioridad: Geoapify (gratis 3k/día) → Photon (OSM POIs) → Nominatim (direcciones formales)
class GeocodingService {
  final String? geoapifyKey;

  // Centro de Bogotá por defecto para sesgo de proximidad
  static const double _defaultLat = 4.6097;
  static const double _defaultLng = -74.0817;

  GeocodingService({this.geoapifyKey});

  /// Limpia el query para geocoders colombianos.
  String _limpiarQuery(String texto) {
    return texto
        .replaceAll(RegExp(r'\bNo\.\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+-\s+'), '-')
        .replaceAll(
          RegExp(r',?\s*(colombia|bogot[aá]|medell[ií]n|cali|barranquilla|bucaramanga)\s*$',
              caseSensitive: false),
          '',
        )
        .trim();
  }

  /// Busca en Geoapify (requiere API key).
  Future<List<ResultadoBusqueda>> _buscarEnGeoapify(String texto) async {
    if (geoapifyKey == null || geoapifyKey!.isEmpty) return [];

    final query = _limpiarQuery(texto);
    final uri = Uri.parse('https://api.geoapify.com/v1/geocode/autocomplete').replace(
      queryParameters: {
        'text': query,
        'filter': 'countrycode:co',
        'bias': 'proximity:$_defaultLng,$_defaultLat',
        'lang': 'es',
        'limit': '6',
        'apiKey': geoapifyKey!,
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body);
      final features = data['features'] as List? ?? [];

      return features.map<ResultadoBusqueda>((f) {
        final p = f['properties'] as Map<String, dynamic>;
        final coords = f['geometry']['coordinates'] as List;

        String nombre;
        if (p['name'] != null) {
          nombre = p['name'] as String;
        } else if (p['street'] != null) {
          final house = p['housenumber'] != null ? ' ${p['housenumber']}' : '';
          nombre = '${p['street']}$house';
        } else {
          nombre = (p['formatted'] as String?)?.split(',').first ?? texto;
        }

        final partes = [
          p['suburb'] ?? p['district'],
          p['city'],
        ].where((e) => e != null).cast<String>().toList();

        return ResultadoBusqueda(
          lat: (coords[1] as num).toDouble(),
          lon: (coords[0] as num).toDouble(),
          nombre: nombre,
          detalle: partes.join(', '),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca en Photon (OSM POIs).
  Future<List<ResultadoBusqueda>> _buscarEnPhoton(String texto) async {
    final uri = Uri.parse('https://photon.komoot.io/api/').replace(
      queryParameters: {
        'q': texto,
        'limit': '5',
        'lang': 'es',
        'lat': '$_defaultLat',
        'lon': '$_defaultLng',
      },
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body);
      final features = data['features'] as List? ?? [];

      return features.map<ResultadoBusqueda>((f) {
        final p = f['properties'] as Map<String, dynamic>;
        final coords = f['geometry']['coordinates'] as List;

        String nombre;
        if (p['name'] != null) {
          nombre = p['name'] as String;
        } else if (p['street'] != null) {
          final house = p['housenumber'] != null ? ' ${p['housenumber']}' : '';
          nombre = '${p['street']}$house';
        } else {
          nombre = texto;
        }

        final partes = [
          p['street'],
          p['district'] ?? p['suburb'],
          p['city'],
        ].where((e) => e != null).cast<String>().toList();

        return ResultadoBusqueda(
          lat: (coords[1] as num).toDouble(),
          lon: (coords[0] as num).toDouble(),
          nombre: nombre,
          detalle: partes.join(', '),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca en Nominatim (direcciones formales).
  Future<List<ResultadoBusqueda>> _buscarEnNominatim(String texto) async {
    final query = texto
        .replaceAll(RegExp(r'\bNo\.\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*#\s*'), ' ')
        .replaceAll(RegExp(r'\s*-\s*(\d)'), r' $1')
        .trim();

    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'q': '$query, Bogotá, Colombia',
        'format': 'json',
        'limit': '4',
        'countrycodes': 'co',
        'addressdetails': '0',
        'viewbox': '-74.2239,4.8368,-73.9961,4.4698',
        'bounded': '0',
      },
    );

    try {
      final res = await http.get(uri, headers: {
        'Accept-Language': 'es',
        'User-Agent': 'RutaLibre/1.0 (co.rutalibre.app)',
      }).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return [];

      final data = json.decode(res.body) as List;
      return data.map<ResultadoBusqueda>((r) {
        final partes = (r['display_name'] as String).split(',').map((s) => s.trim()).toList();
        return ResultadoBusqueda(
          lat: double.parse(r['lat'] as String),
          lon: double.parse(r['lon'] as String),
          nombre: partes.take(2).join(', '),
          detalle: partes.skip(2).take(2).join(', '),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca dirección con cascada de proveedores.
  Future<List<ResultadoBusqueda>> buscarDireccion(String texto) async {
    // Intentar Geoapify primero si hay API key
    if (geoapifyKey != null && geoapifyKey!.isNotEmpty) {
      final resultados = await _buscarEnGeoapify(texto);
      if (resultados.isNotEmpty) return resultados;
    }

    // Photon + Nominatim en paralelo
    final futures = await Future.wait([
      _buscarEnPhoton(texto),
      _buscarEnNominatim(texto),
    ]);

    final photon = futures[0];
    final nominatim = futures[1];

    // Deduplicar por coordenadas cercanas
    final vistos = <String>{};
    return [...photon, ...nominatim].where((r) {
      final k = '${r.lat.toStringAsFixed(3)},${r.lon.toStringAsFixed(3)}';
      if (vistos.contains(k)) return false;
      vistos.add(k);
      return true;
    }).take(7).toList();
  }
}
