import 'dart:async';
import 'dart:ui' as ui; // For platformViewRegistry (web)
import 'dart:html' as html; // For IFrameElement (web)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_fonts/google_fonts.dart';
import 'package:invitacion_boda/widgets/carrusel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:invitacion_boda/services/sheets_services.dart';

class InvitacionPage extends StatefulWidget {
  const InvitacionPage({super.key});

  @override
  State<InvitacionPage> createState() => _InvitacionPageState();
}
class _InvitacionPageState extends State<InvitacionPage> {
    // Cuenta regresiva estilo reloj (HH:MM:SS) hasta el 13 de diciembre de 2025
  Timer? _countdownTimer;
  int _d = 0, _h = 0, _m = 0, _s = 0;
  bool _mapRegistered = false;
  
  // Audio
  late final AudioPlayer _player;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<html.Event>? _firstGestureSub;
  // Form controllers
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _acompananteCtrl = TextEditingController();
  final TextEditingController _acompanante2Ctrl = TextEditingController();
  final TextEditingController _acompanante3Ctrl = TextEditingController();
  int? _passesForTypedName;
  List<Map<String, dynamic>> _nameSuggestions = [];
  bool _soldOut = false;
  Timer? _searchDebounce;
  bool _isConfirming = false;

  void _onNameChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), _runNameSearch);
  }

  Future<void> _runNameSearch() async {
    final raw = _nombreCtrl.text;
    final name = raw.trim();
    if (name.length < 2) {
      if (!mounted) return;
      setState(() {
        _nameSuggestions = [];
        _passesForTypedName = null;
      });
      return;
    }
    try {
      final results = await SheetsService.search(name.toLowerCase());
      // results: List of maps with key_normalized, display, passesRemaining
      if (!mounted) return;
      setState(() {
        _nameSuggestions = results.cast<Map<String, dynamic>>();
      });
      // Si hay coincidencia exacta por display o por key, actualizar pases
      final nameLower = name.toLowerCase();
      final exact = _nameSuggestions.firstWhere(
        (e) => ((e['display'] ?? '').toString().toLowerCase().trim()) == nameLower,
        orElse: () => {},
      );
      if (exact.isNotEmpty) {
        final p = int.tryParse(exact['passesRemaining'].toString());
        if (mounted) {
          setState(() {
            _passesForTypedName = p;
            final pp = p ?? 0;
            if (pp < 2) {
              _acompananteCtrl.clear();
              _acompanante2Ctrl.clear();
              _acompanante3Ctrl.clear();
            } else if (pp == 2) {
              _acompanante2Ctrl.clear();
              _acompanante3Ctrl.clear();
            } else if (pp == 3) {
              _acompanante3Ctrl.clear();
            }
          });
        }
      } else {
        // Si no hay exacto, limpiar pases para que no muestre acompañante incorrectamente
        if (mounted) {
          setState(() {
            _passesForTypedName = null;
            _acompananteCtrl.clear();
            _acompanante2Ctrl.clear();
            _acompanante3Ctrl.clear();
          });
        }
      }
    } catch (e) {
      debugPrint('Name search error: $e');
    }
  }

  Future<void> _refreshSoldOutFromSheets() async {
    try {
      final hasAny = await SheetsService.status();
      if (mounted) setState(() => _soldOut = !hasAny);
    } catch (_) {}
  }

  void _startCountdown() {
    void calc() {
      final now = DateTime.now();
      final target = DateTime(2025, 12, 13);
      Duration diff = target.difference(now);
      if (diff.isNegative) diff = Duration.zero;
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      final seconds = diff.inSeconds % 60;
      if (mounted) {
        setState(() {
          _d = days;
          _h = hours;
          _m = minutes;
          _s = seconds;
        });
      }
    }

    calc();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => calc());
  }
  void _abrirGoogleMaps() async {
    const url =
        "https://www.google.com/maps/place/4%C2%B007'40.7%22N+76%C2%B013'08.4%22W/@4.1279635,-76.2215614,17z/data=!3m1!4b1!4m4!3m3!8m2!3d4.1279635!4d-76.2189865?entry=ttu&g_ep=EgoyMDI1MTAwMS4wIKXMDSoASAFQAw%3D%3D"; // cámbialo por tu ubicación real
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _enviarWhatsApp(String nombre, String acompanante) async {
    if (nombre.isEmpty) {
      return;
    }
    final String mensaje = acompanante.isEmpty
        ? "Hola! Soy $nombre y confirmo mi asistencia para asistir a este evento tan importante el día 13/12/25"
        : "Hola! Soy $nombre y confirmo mi asistencia con $acompanante para asistir a este evento tan importante el día 13/12/25";

    // Previsualización del mensaje antes de enviar
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Previsualización del mensaje'),
        content: SingleChildScrollView(child: Text(mensaje)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final url =
        "https://wa.me/573217815442?text=${Uri.encodeComponent(mensaje)}"; // cámbialo por tu número de WhatsApp
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

// 🔹 Ciclo de vida y build (ajustado)
@override
void initState() {
  super.initState();
  // Register Google Map iframe for web
  if (kIsWeb && !_mapRegistered) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('gmap-iframe', (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.google.com/maps?q=4.1279635,-76.2215614&z=16&output=embed'
        ..style.border = '0'
        ..allowFullscreen = true;
      return iframe;
    });
    _mapRegistered = true;
  }
  _startCountdown();
  // Iniciar música en loop
  _player = AudioPlayer();
  _player.setReleaseMode(ReleaseMode.loop);
  if (kIsWeb) {
    // En Web, intentar autoplay en silencio y luego hacer fade-in.
    _tryAutoplayWeb();
  } else {
    // En móviles/escritorio sí podemos intentar autoplay
    _startAudio();
  }

  // Escuchar cambios de estado del reproductor para reflejar _isPlaying
  _playerStateSub = _player.onPlayerStateChanged.listen((state) {
    final playing = state == PlayerState.playing;
    if (mounted && playing != _isPlaying) {
      setState(() {
        _isPlaying = playing;
      });
    }
  }, onError: (e, st) {
    debugPrint('Audio state error: $e');
  });
  // Escuchar cambios en el nombre para mostrar/ocultar acompañante
  _nombreCtrl.addListener(_onNameChanged);
  // Estado inicial de cupos
  _refreshSoldOutFromSheets();
}

@override
void dispose() {
  _countdownTimer?.cancel();
  _playerStateSub?.cancel();
  _firstGestureSub?.cancel();
  _player.dispose();
  _nombreCtrl.removeListener(_onNameChanged);
  _nombreCtrl.dispose();
  _acompananteCtrl.dispose();
  _acompanante2Ctrl.dispose();
  _acompanante3Ctrl.dispose();
  _searchDebounce?.cancel();
  super.dispose();
}

Future<void> _tryAutoplayWeb() async {
  // Intenta reproducir en silencio y luego hacer fade-in
  try {
    await _player.setVolume(0.0);
    await _player.play(UrlSource('assets/lib/assets/audio/TuPoeta.mp3'));
    // Fade-in suave a 1.0
    await _fadeInVolume(target: 1.0, steps: 10, totalDurationMs: 1200);
  } catch (e) {
    // Si el navegador lo bloquea, armar listener del primer gesto global
    _armFirstGestureToStart();
  }
}

void _armFirstGestureToStart() {
  // Escuchamos el primer click en el documento para iniciar el audio sin overlay
  _firstGestureSub?.cancel();
  _firstGestureSub = html.document.onClick.listen((_) async {
    try {
      await _player.setVolume(0.0);
      await _player.play(UrlSource('assets/lib/assets/audio/TuPoeta.mp3'));
      await _fadeInVolume(target: 1.0, steps: 10, totalDurationMs: 1000);
    } catch (e) {
      debugPrint('Autoplay after first gesture error: $e');
    } finally {
      _firstGestureSub?.cancel();
      _firstGestureSub = null;
    }
  });
}

Future<void> _fadeInVolume({required double target, int steps = 8, int totalDurationMs = 800}) async {
  final double start = 0.0;
  final double delta = (target - start) / steps;
  final int stepDelay = (totalDurationMs / steps).round();
  for (int i = 1; i <= steps; i++) {
    await Future.delayed(Duration(milliseconds: stepDelay));
    await _player.setVolume((start + delta * i).clamp(0.0, 1.0));
  }
}

Future<void> _togglePlayPause() async {
  try {
    if (_isPlaying) {
      await _player.pause();
    } else {
      // Si nunca inició por bloqueo, intenta reproducir desde el asset
      if (kIsWeb) {
        // En Web, iniciar reproducción explícita tras interacción del usuario
        await _player.setVolume(1.0);
        await _player.play(UrlSource('assets/lib/assets/audio/TuPoeta.mp3'));
      } else {
        if (_player.source == null) {
          await _player.play(AssetSource('lib/assets/audio/TuPoeta.mp3'));
        } else {
          await _player.resume();
        }
      }
    }
    // _isPlaying se actualiza por el listener onPlayerStateChanged
  } catch (e) {
    debugPrint('Play/Pause error: $e');
    // Opcional: mostrar un SnackBar con el error
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reproducir/pausar el audio.')),
      );
    }
  }
}

Future<void> _startAudio() async {
  try {
    await _player.play(AssetSource('lib/assets/audio/TuPoeta.mp3'));
    // _isPlaying se actualizará por el listener onPlayerStateChanged
  } catch (e) {
    debugPrint('Start audio error: $e');
  }
}

String _humanJoin(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  if (items.length == 2) return '${items[0]} y ${items[1]}';
  final head = items.sublist(0, items.length - 1).join(', ');
  return '$head y ${items.last}';
}

// 🔹 Dentro del build (ajustado)
@override
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final double fontSizeTitle = size.width * 0.07; // título grande
  final double fontSizeBody = size.width * 0.045; // texto secundario

  final TextEditingController nombreCtrl = _nombreCtrl;
  final TextEditingController acompananteCtrl = _acompananteCtrl;

  return Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: _togglePlayPause,
      backgroundColor: Color(0xFF001F54), // Azul navy
      elevation: 5,
      hoverElevation: 10,
      focusElevation: 10,
      highlightElevation: 10,
      hoverColor: Colors.white,
      tooltip: "Tu Poeta - Alex Campo",
      child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        // 🔹 Fondo único en toda la pantalla
        Image.asset(
          "lib/assets/fondo1.jpg",
          fit: BoxFit.cover,
        ),
        Container(color: Colors.black.withOpacity(0.45)), // filtro oscuro
        _buildSideBars(size),
        // 🔹 Contenido desplazable encima
        SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 Sección 1
              Container(
                height:  size.width > 600 ? size.height * 2.1 : size.height * 1.1,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Barras laterales
                    // Contenido
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20), 
                        // Monograma fijo antes del texto
                        SizedBox(
                          // height: size.width > 600 ? size.height * 0.18 : size.height * 0.14,
                          child: Image.asset(
                            "lib/assets/",
                            height: size.width > 600 ? size.height * 0.18 : size.height * 0.14,
                          ),
                        ),
                        const SizedBox(height: 25),
                        // Carrusel más centrado y uniforme
                        CarruselConDots(),
                        const SizedBox(height: 15),
                        FittedBox(
                          child: Text(
                            "Estas invitado por nosotros",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.parisienne(
                              fontSize: fontSizeTitle,
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(2, 2)),
                              ],
                            ),
                          ),
                        ),
                        FittedBox(
                          child: Text(
                            "ANDRES & DEVY 💌",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ropaSans(
                              fontSize: fontSizeTitle,
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(2, 2)),
                              ],
                            ),
                          ),
                        ),
                        FittedBox(
                          child: Text(
                            "Para compartir\n este momento tan especial 💍",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.parisienne(
                              fontSize: fontSizeTitle,
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(2, 2)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 🔔 Cuenta regresiva (reloj HH:MM:SS)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Etiqueta superior
                      FittedBox(
                        child: Text(
                          "Faltan:",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ropaSans(
                            fontSize: size.width > 600 ? size.width * 0.03 : size.width * 0.06,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(1, 1)),
                            ],
                          ),
                        ),
                      ),
                      // Reloj en bloques: Días | Horas | Minutos | Segundos
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Días
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                child: Text(
                                  '$_d:',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                'Días',
                                style: GoogleFonts.roboto(
                                  fontSize: size.width > 600 ? size.width * 0.02 : size.width * 0.045,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: size.width > 600 ? 24 : 12),
                          // Horas
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                child: Text(
                                  '${_h.toString().padLeft(2, '0')}:',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Horas',
                                style: GoogleFonts.roboto(
                                  fontSize: size.width > 600 ? size.width * 0.02 : size.width * 0.045,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: size.width > 600 ? 24 : 12),
                          // Minutos
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                child: Text(
                                  '${_m.toString().padLeft(2, '0')}:',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                'Minutos',
                                style: GoogleFonts.roboto(
                                  fontSize: size.width > 600 ? size.width * 0.02 : size.width * 0.045,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: size.width > 600 ? 24 : 12),
                          // Segundos
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                child: Text(
                                  _s.toString().padLeft(2, '0'),
                                  style: GoogleFonts.robotoMono(
                                    fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: const [
                                      Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2)),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                'Segundos',
                                style: GoogleFonts.roboto(
                                  fontSize: size.width > 600 ? size.width * 0.02 : size.width * 0.045,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Etiqueta inferior
                      FittedBox(
                        child: Text(
                          "Para este evento tan importante",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ropaSans(
                            fontSize: size.width > 600 ? size.width * 0.03 : size.width * 0.055,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(1, 1)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 🔹 Sección 2
              Container(
                height:  size.width > 600 ? size.height * 4.2 : size.height * 2.0,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: size.width > 600 ? size.height * 0.8 : size.height * 0.6,
                              width: size.width > 600 ? size.width * 0.8 : size.width * 0.6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: AssetImage("lib/assets/IMG_1536.jpg"),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            FittedBox(
                              child: Text(
                                "Oseas 2:19",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeTitle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              child: Text(
                                "Te haré mi esposa para siempre.\nTe haré mi esposa con derecho y justicia,\nen gran amor y compasión",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dancingScript(
                                  fontSize: fontSizeBody + 2,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              child: Text(
                                "13 de diciembre de 2025 \n a las 05:00PM",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Calendario Diciembre 2025 con corazón en el 13
                            _buildDecemberCalendar(),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_pin,
                                  color: Colors.amberAccent,
                                  size: fontSizeTitle + 5
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "Villa Alicia",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: fontSizeTitle,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Mapa embebido (solo Web)
                            if (kIsWeb)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: size.width > 600 ? size.width * 0.6 : size.width * 0.85,
                                  height: 320,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const HtmlElementView(viewType: 'gmap-iframe'),
                                ),
                              )
                            else
                            Container(
                              width: size.width > 600 ? size.width * 0.6 : size.width * 0.85,
                              height: 200,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                'El mapa embebido está disponible en la versión Web.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: fontSizeBody,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              onPressed: _abrirGoogleMaps,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade400,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text("Ver en Google Maps"),
                            ),
                            // Padding(
                            //   padding: EdgeInsets.symmetric(horizontal:  size.width * 0.12),
                            //   child: Column(
                            //     mainAxisSize: MainAxisSize.min,
                            //     children: [
                            //       const SizedBox(height: 20),
                            //       ClipRRect(
                            //         borderRadius: BorderRadius.circular(20),
                            //         child: Image.asset(
                            //           "lib/assets/IMG_1540.jpg",
                            //           width:  size.width > 600 ? size.width * 0.5 : size.width * 0.8,
                            //           height:  size.width > 600 ? 400 : size.height * 0.80,
                            //           fit: BoxFit.cover,
                            //         ),
                            //       ),
                            //     ],
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 🔹 Sección 3
              Container(
                width: double.infinity,
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        "Recomendaciones",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: fontSizeTitle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.8,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "1. ",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "¿Tienes dudas o necesitas ayuda?\n",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "¡Contáctanos! Estamos aquí para acompañarte y \nresolver cualquier detalle con todo el cariño. 💌",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.8,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "2. ",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Llega a tiempo ⏰\n",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Cada momento ha sido preparado con amor y queremos\nque vivas la experiencia completa desde el inicio.",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.8,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "3. ",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Ríe, baila y disfruta 💃\n",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Este día está hecho para celebrar, compartir y\ncrear recuerdos que durarán para siempre. 🕺🏻💃🏼",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.8,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "4. ",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Código de vestimenta 👗🤵\n",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Te sugerimos vestir elegante y cómodo, acorde al\nencanto de este día tan especial.\n",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Hombres:",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: " Camisa - Pantalon 👔\n",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Mujeres:",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: " Vestido 👗",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.8,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "5. ",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Comparte con amor 💖\n",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeBody - 0.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Tu presencia es nuestro mejor regalo, pero sobre todo,\nven con la mejor energía y disposición para disfrutar.",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Aviso: Lluvia de sobres
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.8,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Regalo: Lluvia de sobres\n",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeTitle,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: "Si deseas honrarnos con un detalle, agradecemos una lluvia de sobres. 💌\n",
                                style: GoogleFonts.nunito(
                                  fontSize: fontSizeBody - 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Aviso: No niños + GIF
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Por favor, sin niños\n",
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: fontSizeBody - 0.2,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: "Queremos que disfrutes plenamente este momento especial. ❤️\n",
                                    style: GoogleFonts.nunito(
                                      fontSize: fontSizeBody - 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // GIF informativo
                            Image.asset(
                              "lib/assets/noniños.gif",
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: size.width * 0.12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            if (_soldOut)
                              Container(
                                width: size.width > 600 ? 480 : size.width * 0.85,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  '¡Los cupos están a tope! 💥🎉\n\nYa casi comienza la celebración... ¡nos vemos pronto para vivir este día inolvidable! 🥳💍',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: fontSizeBody,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                            SizedBox(
                              width:  size.width > 600 ? 400 : size.width * 0.75,
                              child: TextField(
                                controller: nombreCtrl,
                                decoration: const InputDecoration(
                                  labelText: "Tu nombre",
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                              ),
                            ),
                            // Sugerencias de nombre (typeahead desde Sheets)
                            if (_nameSuggestions.isNotEmpty)
                              Container(
                                width: size.width > 600 ? 400 : size.width * 0.75,
                                constraints: const BoxConstraints(maxHeight: 180),
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: ListView.builder(
                                  itemCount: _nameSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final item = _nameSuggestions[index];
                                    final display = (item['display'] ?? '').toString();
                                    final passesRem = int.tryParse(item['passesRemaining']?.toString() ?? '');
                                    return ListTile(
                                      dense: true,
                                      title: Text(display),
                                      onTap: () {
                                        setState(() {
                                          _nombreCtrl.text = display;
                                          _nombreCtrl.selection = TextSelection.collapsed(offset: display.length);
                                          _passesForTypedName = passesRem;
                                          _nameSuggestions = [];
                                          if ((passesRem ?? 0) < 2) _acompananteCtrl.clear();
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (_passesForTypedName != null)
                            SizedBox(
                              width: size.width > 600 ? 400 : size.width * 0.75,
                              child: Text(
                                'Tienes ${_passesForTypedName} pases disponibles. Puedes añadir hasta ${((_passesForTypedName ?? 1) - 1).clamp(0, 3)} acompañantes.',
                                style: GoogleFonts.roboto(color: Colors.white, fontSize: fontSizeBody * 0.55, fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (!_soldOut)
                              ...((){
                                final p = _passesForTypedName ?? 0;
                                final maxCompanions = (p - 1).clamp(0, 3);
                                final widgets = <Widget>[];
                                if (maxCompanions >= 1) {
                                  widgets.add(SizedBox(
                                    width: size.width > 600 ? 400 : size.width * 0.75,
                                    child: TextField(
                                      controller: acompananteCtrl,
                                      decoration: const InputDecoration(
                                        labelText: "Acompañante 1",
                                        filled: true,
                                        fillColor: Colors.white70,
                                      ),
                                    ),
                                  ));
                                  widgets.add(const SizedBox(height: 8));
                                }
                                if (maxCompanions >= 2) {
                                  widgets.add(SizedBox(
                                    width: size.width > 600 ? 400 : size.width * 0.75,
                                    child: TextField(
                                      controller: _acompanante2Ctrl,
                                      decoration: const InputDecoration(
                                        labelText: "Acompañante 2",
                                        filled: true,
                                        fillColor: Colors.white70,
                                      ),
                                    ),
                                  ));
                                  widgets.add(const SizedBox(height: 8));
                                }
                                if (maxCompanions >= 3) {
                                  widgets.add(SizedBox(
                                    width: size.width > 600 ? 400 : size.width * 0.75,
                                    child: TextField(
                                      controller: _acompanante3Ctrl,
                                      decoration: const InputDecoration(
                                        labelText: "Acompañante 3",
                                        filled: true,
                                        fillColor: Colors.white70,
                                      ),
                                    ),
                                  ));
                                }
                                return widgets;
                              }()),
                            const SizedBox(height: 20),
                            if (!_soldOut)
                            ElevatedButton(
                              onPressed: _isConfirming ? null : () async {
                                final nombre = nombreCtrl.text.trim();
                                final acomp1 = acompananteCtrl.text.trim();
                                final acomp2 = _acompanante2Ctrl.text.trim();
                                final acomp3 = _acompanante3Ctrl.text.trim();
                                if (nombre.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ingresa tu nombre para confirmar.'), duration: Duration(seconds: 2), width: 200, backgroundColor: Colors.red,),
                                  );
                                  return;
                                }
                                setState(() => _isConfirming = true);
                                try {
                                  // Consultar invitado en Sheets
                                  final guest = await SheetsService.getGuest(nombre);
                                  if (guest == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No encontramos tu nombre. Escríbelo exactamente como aparece en la invitación.'), duration: Duration(seconds: 2), width: 200, backgroundColor: Colors.red,),
                                    );
                                    return;
                                  }

                                  final passes = int.tryParse(guest['passesRemaining']?.toString() ?? '0') ?? 0;
                                  if (passes <= 0) {
                                    await _refreshSoldOutFromSheets();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Ya no quedan pases disponibles para este nombre.'), duration: Duration(seconds: 2), width: 260, backgroundColor: Colors.red,),
                                    );
                                    return;
                                  }

                                  // Consumir pases considerando hasta 3 acompañantes
                                  final companionsInput = [acomp1, acomp2, acomp3]
                                      .where((s) => s.isNotEmpty)
                                      .toList();
                                  int desired = 1 + companionsInput.length; // invitado + acompañantes
                                  if (desired > passes) {
                                    // recortar acompañantes a los cupos disponibles
                                    final allowedCompanions = (passes - 1).clamp(0, 3);
                                    companionsInput.removeRange(allowedCompanions, companionsInput.length);
                                    desired = 1 + companionsInput.length;
                                  }
                                  final updated = await SheetsService.confirm(nombre, consume: desired);
                                  if (updated == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No se pudo confirmar. Intenta de nuevo.'), duration: Duration(seconds: 2), width: 240, backgroundColor: Colors.red,),
                                    );
                                    return;
                                  }

                                  String acompFinal = '';
                                  if (companionsInput.isNotEmpty) {
                                    acompFinal = _humanJoin(companionsInput);
                                  }
                                  _enviarWhatsApp(nombre, acompFinal);
                                  // Recalcular estado de cupos (optimista) y luego confirmar con Sheets
                                  if (mounted) {
                                    setState(() {
                                      _soldOut = false;
                                    });
                                  }
                                  await _refreshSoldOutFromSheets();
                                } finally {
                                  if (mounted) setState(() => _isConfirming = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text("Confirmar asistencia 💌"),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ]
    ),
  );
}

  // 🔹 Calendario simple: Diciembre 2025 con corazón en el día 13
  Widget _buildDecemberCalendar() {
    final size = MediaQuery.of(context).size;
    final monthStart = DateTime(2025, 12, 1);
    final daysInMonth = DateTime(2026, 1, 0).day; // 31
    final startWeekday = monthStart.weekday; // 1=Lun ... 7=Dom

    final leadingEmpty = startWeekday - 1; // celdas vacías antes del 1
    final cells = leadingEmpty + daysInMonth;
    final totalCells = ((cells + 6) ~/ 7) * 7; // múltiplo de 7

    TextStyle headerStyle = GoogleFonts.roboto(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: size.width > 600 ? 14 : 10,
      shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))],
    );

    TextStyle dayStyle = GoogleFonts.roboto(
      color: Colors.white,
      fontWeight: FontWeight.w500,
      fontSize: size.width > 600 ? 16 : 12,
      shadows: const [Shadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))],
    );

    Widget dayCell(int? day) {
      final isMarked = day == 13;
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isMarked ? Colors.amber.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: day == null
            ? const SizedBox.shrink()
            : Stack(
              children: [
                // if (isMarked) const SizedBox(height: 1.5),
                if (isMarked)
                  Center(
                    child: const Icon(
                      Icons.favorite_border,
                      color: Colors.redAccent,
                      size: 40,
                    ),
                  ),
                Center(child: Text('$day', style: dayStyle)),
              ],
            ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título del mes
        FittedBox(
          child: Text(
            'Diciembre 2025',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: size.width > 600 ? 28 : 22,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(2, 2))],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Encabezado de días
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final w in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
              Expanded(
                child: Center(child: Text(w, style: headerStyle)),
              )
          ],
        ),
        const SizedBox(height: 6),
        // Grilla de días
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.2,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < leadingEmpty) return dayCell(null);
            final day = index - leadingEmpty + 1;
            if (day > daysInMonth) return dayCell(null);
            return dayCell(day);
          },
        ),
      ],
    );
  }

// 🔹 Método para no repetir barras doradas
Widget _buildSideBars(Size size) {
  return Positioned.fill(
    child: Row(
      children: [
        Container(
          width: size.width * 0.1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFA7C7E7), // Azul celeste
                Color(0xFF001F54), // Azul navy
                Color(0xFF0A0A23), // Azul oscuro
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const Spacer(),
        Container(
          width: size.width * 0.1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFA7C7E7), // Azul celeste
                Color(0xFF001F54), // Azul navy
                Color(0xFF0A0A23), // Azul oscuro
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    ),
  );
}

}
