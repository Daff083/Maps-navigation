import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Aplikasi());
}

class Aplikasi extends StatelessWidget {
  const Aplikasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tugas LMS - Peta Wisata',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      themeMode: ThemeMode.light,
      home: const HalamanPeta(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HalamanPeta extends StatefulWidget {
  const HalamanPeta({super.key});

  @override
  State<HalamanPeta> createState() => _HalamanPetaState();
}

class _HalamanPetaState extends State<HalamanPeta>
    with TickerProviderStateMixin {
  final MapController _kontrolerPeta = MapController();

  // Koordinat Telkom University (Bandung) & Gedung Sate
  static const _lokasiTelkomUniversity = LatLng(-6.9740, 107.6303);
  static const _lokasiGedungSate = LatLng(-6.9025, 107.6188);

  bool _diTempatWisata = false;
  bool _sedangMemuatRute = false;
  late List<Marker> _daftarMarker;

  // Data rute
  List<LatLng> _titikRute = [];
  String _jarakTeks = '';
  String _waktuTeks = '';

  @override
  void initState() {
    super.initState();
    // Kondisi awal: Hanya menampilkan marker Telkom University
    _daftarMarker = [
      _buatMarker(
        posisi: _lokasiTelkomUniversity,
        label: 'Telkom University',
        warna: const Color(0xFFD32F2F),
      ),
    ];
  }

  /// Membuat widget Marker custom
  Marker _buatMarker({
    required LatLng posisi,
    required String label,
    required Color warna,
  }) {
    return Marker(
      point: posisi,
      width: 140,
      height: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: warna,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: warna.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Icon(Icons.location_on, color: warna, size: 36),
        ],
      ),
    );
  }

  /// Mengambil data rute dari OSRM
  Future<void> _ambilRute(LatLng asal, LatLng tujuan) async {
    setState(() => _sedangMemuatRute = true);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${asal.longitude},${asal.latitude};'
        '${tujuan.longitude},${tujuan.latitude}'
        '?overview=full&geometries=geojson',
      );

      final respon = await http.get(url);

      if (respon.statusCode == 200) {
        final data = jsonDecode(respon.body);
        final rute = data['routes'][0];

        // Parsing koordinat GeoJSON
        final koordinat = rute['geometry']['coordinates'] as List;
        final titik = koordinat
            .map<LatLng>((k) => LatLng(k[1].toDouble(), k[0].toDouble()))
            .toList();

        final jarakMeter = rute['distance'].toDouble();
        final waktuDetik = rute['duration'].toDouble();

        setState(() {
          _titikRute = titik;
          _jarakTeks = _formatJarak(jarakMeter);
          _waktuTeks = _formatWaktu(waktuDetik);
        });
      }
    } catch (e) {
      debugPrint('Gagal mengambil rute: $e');
    } finally {
      setState(() => _sedangMemuatRute = false);
    }
  }

  String _formatJarak(double meter) {
    if (meter >= 1000) return '${(meter / 1000).toStringAsFixed(1)} km';
    return '${meter.toInt()} m';
  }

  String _formatWaktu(double detik) {
    final menit = (detik / 60).round();
    if (menit >= 60) {
      final jam = menit ~/ 60;
      final sisaMenit = menit % 60;
      return '$jam jam $sisaMenit mnt';
    }
    return '$menit mnt';
  }

  /// Animasi perpindahan kamera peta
  void _pindahKeLokasi(LatLng tujuan, double zoomTujuan) {
    final posisiAwal = _kontrolerPeta.camera.center;
    final zoomAwal = _kontrolerPeta.camera.zoom;

    final kontrolerAnimasi = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    final animasi = CurvedAnimation(
      parent: kontrolerAnimasi,
      curve: Curves.easeInOut,
    );

    kontrolerAnimasi.addListener(() {
      final lat = posisiAwal.latitude +
          (tujuan.latitude - posisiAwal.latitude) * animasi.value;
      final lng = posisiAwal.longitude +
          (tujuan.longitude - posisiAwal.longitude) * animasi.value;
      final zoom = zoomAwal + (zoomTujuan - zoomAwal) * animasi.value;

      _kontrolerPeta.move(LatLng(lat, lng), zoom);
    });

    kontrolerAnimasi.addStatusListener((status) {
      if (status == AnimationStatus.completed) kontrolerAnimasi.dispose();
    });

    kontrolerAnimasi.forward();
  }

  /// Menyesuaikan kamera agar rute terlihat penuh
  void _tampilkanSemuaLokasi() {
    final bounds = LatLngBounds.fromPoints([
      _lokasiTelkomUniversity,
      _lokasiGedungSate,
    ]);

    Future.delayed(const Duration(milliseconds: 100), () {
      _kontrolerPeta.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 60, bottom: 180, left: 60, right: 60),
        ),
      );
    });
  }

  /// Tombol aksi ganti lokasi
  void _toggleLokasi() async {
    setState(() => _diTempatWisata = !_diTempatWisata);

    if (_diTempatWisata) {
      setState(() {
        _daftarMarker = [
          _buatMarker(
            posisi: _lokasiTelkomUniversity,
            label: 'Telkom University',
            warna: const Color(0xFFD32F2F),
          ),
          _buatMarker(
            posisi: _lokasiGedungSate,
            label: 'Wisata: Gedung Sate',
            warna: const Color(0xFF1565C0),
          ),
        ];
      });

      await _ambilRute(_lokasiTelkomUniversity, _lokasiGedungSate);
      _tampilkanSemuaLokasi();
    } else {
      setState(() {
        _daftarMarker = [
          _buatMarker(
            posisi: _lokasiTelkomUniversity,
            label: 'Telkom University',
            warna: const Color(0xFFD32F2F),
          ),
        ];
        _titikRute = [];
        _jarakTeks = '';
        _waktuTeks = '';
      });
      _pindahKeLokasi(_lokasiTelkomUniversity, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Peta Telkom - Wisata',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: tema.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _kontrolerPeta,
            options: MapOptions(
              initialCenter: _lokasiTelkomUniversity,
              initialZoom: 16.0,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.tugaslms',
              ),
              
              // Garis rute warna biru
              if (_titikRute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _titikRute,
                      strokeWidth: 5.0,
                      color: const Color(0xFF1565C0), // Warna biru mirip Google Maps
                    ),
                  ],
                ),

              MarkerLayer(markers: _daftarMarker),
            ],
          ),

          // Info jarak & waktu (muncul saat rute dimuat)
          if (_diTempatWisata && _jarakTeks.isNotEmpty)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: tema.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _InfoRute(
                      ikon: Icons.straighten_rounded,
                      label: 'Jarak',
                      nilai: _jarakTeks,
                    ),
                    Container(
                      height: 28,
                      width: 1,
                      color: tema.onSurface.withValues(alpha: 0.1),
                    ),
                    _InfoRute(
                      ikon: Icons.access_time_rounded,
                      label: 'Estimasi',
                      nilai: _waktuTeks,
                    ),
                  ],
                ),
              ),
            ),
            
          // Loading indicator saat ambil data rute
          if (_sedangMemuatRute)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sedangMemuatRute ? null : _toggleLokasi,
        backgroundColor: _diTempatWisata
            ? const Color(0xFFD32F2F)
            : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: Icon(
          _diTempatWisata ? Icons.school_rounded : Icons.tour_rounded,
        ),
        label: Text(
          _diTempatWisata ? 'Kembali ke Kampus' : 'Rute ke Wisata',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// Widget untuk panel info di bagian bawah
class _InfoRute extends StatelessWidget {
  final IconData ikon;
  final String label;
  final String nilai;

  const _InfoRute({
    required this.ikon,
    required this.label,
    required this.nilai,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 22, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: tema.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              nilai,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: tema.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}