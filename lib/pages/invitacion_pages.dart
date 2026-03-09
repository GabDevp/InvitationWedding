// ignore_for_file: unused_field, unused_local_variable

import 'dart:async';
import 'dart:ui_web' as ui; // For platformViewRegistry (web)
import 'dart:html' as html; // For IFrameElement (web)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:invitacion_boda/widgets/carrusel.dart';
import 'package:invitacion_boda/services/sheets_services.dart';
import 'package:video_player/video_player.dart';

class InvitacionPage extends StatefulWidget {
  final String? guestName;
  final String? guestDisplayName;
  final int? guestPasses;
  
  const InvitacionPage({super.key, this.guestName, this.guestDisplayName, this.guestPasses});

  @override
  State<InvitacionPage> createState() => _InvitacionPageState();
}
class _InvitacionPageState extends State<InvitacionPage> with TickerProviderStateMixin {
    // Cuenta regresiva estilo reloj (HH:MM:SS) hasta el 13 de diciembre de 2025
  Timer? _countdownTimer;
  int _d = 0, _h = 0, _m = 0, _s = 0;
  bool _mapRegistered = false;

  bool _alreadyConfirmed = false;
  
  // Audio
  late final AudioPlayer _player;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<html.Event>? _firstGestureSub;

  // Video
  late final VideoPlayerController _videoController;

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
  // Control de búsqueda al seleccionar una sugerencia
  String? _selectedNameDisplay;
  bool _ignoreNextNameChange = false;
  
  // Datos del invitado desde la ruta del envelope
  String? _guestNameFromRoute;
  String? _guestDisplayNameFromRoute;
  int? _guestPassesFromRoute;

  void _onNameChanged() {
    // Evitar disparar búsqueda cuando acabamos de setear el texto por selección
    if (_ignoreNextNameChange) {
      _ignoreNextNameChange = false;
      return;
    }
    final current = _nombreCtrl.text.trim();
    if (_selectedNameDisplay != null && current == _selectedNameDisplay) {
      // Mantener selección: no buscar
      return;
    }
    // Si el usuario cambió el texto respecto a la selección, liberar selección y buscar
    _selectedNameDisplay = null;
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
      final target = DateTime(2026, 3, 21);
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
    const url = "https://www.google.com/maps?q=4.08949613571167,-76.23393249511719&z=17&hl=en";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _enviarWhatsApp(String nombre, String acompanante) async {
    if (nombre.isEmpty) {
      return;
    }
    final String mensaje = _guestPassesFromRoute! == 1 
        ? "Hola! Soy $nombre y confirmo mi asistencia para asistir a este evento tan importante el día 21/03/26"
        : "Hola! Soy $nombre y confirmo mi asistencia con $_guestPassesFromRoute pases para asistir a este evento tan importante el día 21/03/26";

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
            onPressed: () {
              setState(() {
                _guestPassesFromRoute = 0; // Actualizar pases a 0 después de confirmar
              });
                Navigator.of(ctx).pop(true);
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final url =
        "https://wa.me/573173668908?text=${Uri.encodeComponent(mensaje)}"; // cámbialo por tu número de WhatsApp
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
  
  // Nueva función de confirmación con datos de la ruta
  void _confirmarAsistenciaDesdeRuta() async {
    if (_guestDisplayNameFromRoute == null) return;
    
    // Verificar si está dentro del plazo de 5 días
    final now = DateTime.now();
    final deadline = DateTime(2026, 3, 16); // 5 días antes del evento
    final daysRemaining = deadline.difference(now).inDays;
    
    // Mostrar diálogo de confirmación con mensaje de 5 días
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar Asistencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitado: $_guestDisplayNameFromRoute'),
            Text('Pases disponibles: $_guestPassesFromRoute'),
            SizedBox(height: 10),
            if (daysRemaining < 0)
              Text(
                'El plazo para confirmar ha finalizado',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                daysRemaining > 0 
                  ? 'Tienes $daysRemaining días para confirmar tu asistencia'
                  : 'Último día para confirmar',
                style: TextStyle(
                  color: daysRemaining > 2 ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            SizedBox(height: 10),
            if (daysRemaining < 0)
              Text('Ya no es posible confirmar la asistencia.')
            else
              Text('¿Deseas confirmar tu asistencia?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cerrar'),
          ),
          (daysRemaining >= 0 && !_alreadyConfirmed) ?
            ElevatedButton(
              onPressed: () async {
                // Descontar pases automáticamente
                try {
                  await SheetsService.confirm(_guestNameFromRoute!, consume: int.parse(_guestPassesFromRoute.toString()));
                  Navigator.of(ctx).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡Asistencia confirmada! $_guestPassesFromRoute pases descontados'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() {
                    _alreadyConfirmed = true;
                  });
                  // Enviar WhatsApp después de confirmar
                  _enviarWhatsApp(_guestDisplayNameFromRoute!, "");
                } catch (e) {
                  Navigator.of(ctx).pop(false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al confirmar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Confirmar'),
            ) : Text(
              "Muchas gracias por confirmar.\nNos vemos pronto 💍",
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _checkIfConfirmed() async {
    if (_guestNameFromRoute == null) return;

    try {
      final guest = await SheetsService.getGuest(_guestNameFromRoute!);

      if (guest != null) {
        final passes = int.tryParse(guest['passesRemaining'].toString()) ?? 0;

        if (mounted) {
          setState(() {
            _alreadyConfirmed = passes == 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error verificando confirmación: $e");
    }
  }

// 🔹 Ciclo de vida y build (ajustado)
@override
void initState() {
  super.initState();
  
  // Inicializar datos del invitado desde la ruta
  _guestNameFromRoute = widget.guestName;
  _guestPassesFromRoute = widget.guestPasses;
  _guestDisplayNameFromRoute = widget.guestDisplayName;
  
  // Si hay nombre desde la ruta, establecerlo en el campo
  if (_guestNameFromRoute != null) {
    _nombreCtrl.text = _guestNameFromRoute!;
    _selectedNameDisplay = _guestNameFromRoute;
    _passesForTypedName = _guestPassesFromRoute;
  }
  
  if (kIsWeb && !_mapRegistered) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('gmap-iframe', (int viewId) {
      final iframe = html.IFrameElement()
        ..src = 'https://www.openstreetmap.org/export/embed.html?bbox=-76.2379325%2C4.0884961%2C-76.2299325%2C4.0904961&layer=mapnik&marker=4.0894961%2C-76.2339325'
        ..style.border = '0'
        ..allowFullscreen = true;
      return iframe;
    });
    _mapRegistered = true;
  }
  _startCountdown();
  _player = AudioPlayer();
  _player.setReleaseMode(ReleaseMode.loop);
  if (kIsWeb) {
    _tryAutoplayWeb();
  } else {
    _startAudio();
  }

  _videoController = VideoPlayerController.asset('lib/assets/video/invitacion.mp4',videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),)..initialize().then((_) {
    setState(() {});
    _videoController.setLooping(true);
    _videoController.setVolume(0); // sin sonido
    _videoController.play();
  });

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
  // Consulta pases disponibles
  _checkIfConfirmed();
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
  _videoController.dispose();
  super.dispose();
}

Future<void> _tryAutoplayWeb() async {
  // Intenta reproducir en silencio y luego hacer fade-in
  try {
    await _player.setVolume(0.0);
    await _player.play(UrlSource('assets/lib/assets/audio/Fonseca.mp3'));
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
      await _player.play(UrlSource('assets/lib/assets/audio/Fonseca.mp3'));
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
        await _player.play(UrlSource('lib/assets/audio/Fonseca.mp3'));
      } else {
        if (_player.source == null) {
          await _player.play(AssetSource('lib/assets/audio/Fonseca.mp3'));
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
    await _player.play(AssetSource('lib/assets/audio/Fonseca.mp3'));
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
          tooltip: "Fonseca - Que Suerte Tenerte",
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
        Container(color: Colors.black.withOpacity(0.30)), // filtro oscuro
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
                            "lib/assets/5.jpeg",
                            height: size.width > 600 ? size.height * 0.9 : size.height * 0.7,
                          ),
                        ),
                        const SizedBox(height: 15),
                        FittedBox(
                          child: Text(
                            "Esta invitación es única,\nya que eres una de las personas\nmás importantes para nosotros.",
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
                            "Por eso queremos compartir\n este momento tan especial 💍",
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
              Center(
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
                                  fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.11,
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
                                  fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.11,
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
                                  fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.11,
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
                                  fontSize: size.width > 600 ? size.width * 0.05 : size.width * 0.11,
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
              const SizedBox(height: 50),
              // 🔹 Sección 2
              Container(
                height: size.width > 600 ? size.height * 4.2 : 
                !(_guestNameFromRoute?.toLowerCase().contains('carolinal') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('cata') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('luistafur') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('valentina') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('rosario') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('sanjose') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('promotora') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('elsy') ?? false) ? size.height * 2.7 : size.height * 2.0,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Carrusel más centrado y uniforme
                        CarruselConDots(),
                        const SizedBox(height: 50),
                        FittedBox(
                          child: Text(
                            "Provervios 19:6",
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
                            "El corazón del hombre\ntraza su rumbo, pero sus\npasos los dirige el SEÑOR.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dancingScript(
                              fontSize: fontSizeBody + 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          child: Text(
                            "¡Aparta la fecha!",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: fontSizeTitle + 1.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Calendario Marzo 2026 con corazón en el 21
                        _buildCalendar(),
                        const SizedBox(height: 20),
                        Text(
                          "CEREMONIA",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: fontSizeTitle + 2,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // seccion de Eucaristía
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.church_outlined,
                                  color: Colors.amberAccent,
                                  size: 100,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Nombre de la iglesia
                                    Text(
                                      "Parroquia del Salesianos",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: fontSizeBody,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Hora de la eucaristía
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color: Colors.amberAccent,
                                          size: fontSizeTitle,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "3:00 PM",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: fontSizeTitle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                )
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_pin,
                                  color: Colors.amberAccent,
                                  size: fontSizeTitle,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "Carrera 26 #34-18, Barrio Salesianos",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: fontSizeBody,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Ocultar sección de recepción para ciertos invitados
                        if (!(_guestNameFromRoute?.toLowerCase().contains('carolinal') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('cata') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('luistafur') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('valentina') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('rosario') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('sanjose') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('promotora') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('elsy') ?? false))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "RECEPCIÓN",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: fontSizeTitle + 2,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_pin,
                                        color: Colors.amberAccent,
                                        size: fontSizeTitle
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          "VILLA GABRIELA",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: fontSizeBody,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.access_time_filled_outlined,
                                        color: Colors.amberAccent,
                                        size: fontSizeBody
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "5:30 PM",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: fontSizeBody,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    ],
                                  ),
                                  Text(
                                    "Parcelación El Llanito casa 25 Nariño",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: fontSizeBody,
                                      color: Colors.white,
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        const SizedBox(height: 12),
                        // Mapa embebido (solo Web) - Ocultar para ciertos invitados
                        if (kIsWeb && 
                        !(_guestNameFromRoute?.toLowerCase().contains('carolinal') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('cata') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('luistafur') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('valentina') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('rosario') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('sanjose') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('promotora') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('elsy') ?? false)
                            )
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
                        else if (!kIsWeb &&
                        !(_guestNameFromRoute?.toLowerCase().contains('carolinal') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('cata') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('luistafur') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('valentina') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('rosario') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('sanjose') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('promotora') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('elsy') ?? false)
                        )
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
                        if(!(_guestNameFromRoute?.toLowerCase().contains('carolinal') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('cata') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('luistafur') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('valentina') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('rosario') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('sanjose') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('promotora') ?? false) &&
                        !(_guestNameFromRoute?.toLowerCase().contains('elsy') ?? false))
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
                        const SizedBox(height: 30),
                      ],
                    ),
                  ],
                ),
              ),
              // 🔹 Sección 3
              if(!(_guestNameFromRoute?.toLowerCase().contains('carolinal') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('cata') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('luistafur') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('valentina') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('rosario') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('sanjose') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('promotora') ?? false) &&
                !(_guestNameFromRoute?.toLowerCase().contains('elsy') ?? false))
                Container(
                width: double.infinity,
                child: Column(
                  children: [
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
                                text: "¿Tienes dudas o necesitas ayuda?\n",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: fontSizeTitle - 0.5,
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
                      child: ElevatedButton(
                        onPressed: () => _showRecomendacionesDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB08D57),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          "Ver Recomendaciones",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                text: "Regalo:\n",
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
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          if (_soldOut || _guestPassesFromRoute == 0 && 
                          !(_guestNameFromRoute?.toLowerCase().contains('carolinal') ?? false) &&
                          !(_guestNameFromRoute?.toLowerCase().contains('cata') ?? false) &&
                          !(_guestNameFromRoute?.toLowerCase().contains('luistafur') ?? false) &&
                          !(_guestNameFromRoute?.toLowerCase().contains('valentina') ?? false) &&
                          !(_guestNameFromRoute?.toLowerCase().contains('rosario') ?? false) &&
                          !(_guestNameFromRoute?.toLowerCase().contains('sanjose') ?? false) &&
                          !(_guestNameFromRoute?.toLowerCase().contains('promotora') ?? false) &&
                          !(_guestNameFromRoute?.toLowerCase().contains('elsy') ?? false))
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
                          // Botón de confirmación rápida si viene desde la ruta
                          if (_guestNameFromRoute != null && _guestPassesFromRoute != 0)
                          Column(
                            children: [
                              Container(
                                width: size.width > 600 ? 480 : size.width * 0.95,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '¡Hola $_guestDisplayNameFromRoute! 👋',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.playfairDisplay(
                                        color: Colors.white,
                                        fontSize: fontSizeTitle,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tienes $_guestPassesFromRoute pases disponibles',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white,
                                        fontSize: fontSizeBody,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    (!_alreadyConfirmed) ? ElevatedButton(
                                      onPressed: _confirmarAsistenciaDesdeRuta,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[900],
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 30, vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: const Text(
                                        "Confirmar mi asistencia 💌",
                                        style: TextStyle(fontSize: 16, color: Colors.white),
                                      ),
                                    ) : Text(
                                      "Muchas gracias por confirmar.\nNos vemos pronto 💍",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 22,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          )
                        ],
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

  //🔹 Metodo para mostrar recomendaciones
  void _showRecomendacionesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFB08D57),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Recomendaciones",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: MediaQuery.of(context).size.width * 0.07,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Your existing RichText widgets go here, each wrapped in a Padding
                  _buildRecommendationItem(
                    context,
                    number: "1",
                    title: "Llega a tiempo ⏰",
                    description: "Cada momento es creado con amor y queremos que vivas\nla experiencia completa desde el inicio,\npor eso llega puntual a la hora.",
                  ),
                  _buildRecommendationItem(
                    context,
                    number: "2",
                    title: "Disfruta la cena 🍽️",
                    description: "Prepárate para una cena especial donde cada platillo está seleccionado con amor.\nDisfruta de la buena comida y la compañía en esta noche memorable.",
                    showQR: true,
                  ),
                  _buildRecommendationItem(
                    context,
                    number: "3",
                    title: "Código de vestimenta 👗🤵",
                    description: "Hombres: Camisa - Pantalon 👔\nMujeres: Vestido 👗",
                    isDressCode: true,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8C6B1F),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text("Cerrar"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationItem(BuildContext context, {
    required String number,
    required String title,
    required String description,
    bool isDressCode = false,
    bool showQR = false,  // New parameter for QR code
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: "$number. ",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: "$title\n",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (!isDressCode) ...[
                  TextSpan(
                    text: description,
                    style: GoogleFonts.nunito(
                      fontSize: MediaQuery.of(context).size.width * 0.035,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isDressCode) ...[
            Text(
              "Los colores que ven son de muestra pero los colores como: Gris y Marfil, preferimos reservarlos y sobre todo\n El BLANCO, EXCLUSIVO PARA LA NOVIA",
              style: GoogleFonts.nunito(
                fontSize: MediaQuery.of(context).size.width * 0.035,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      "Hombres",
                      style: GoogleFonts.nunito(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 160,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('lib/assets/hombres.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "Mujeres",
                      style: GoogleFonts.nunito(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 160,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('lib/assets/mujeres.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  // 🔹 Calendario simple: Marzo 2026 con corazón en el día 21
  Widget _buildCalendar() {
    final size = MediaQuery.of(context).size;
    final monthStart = DateTime(2026, 3, 1);
    final daysInMonth = DateTime(2026, 4, 0).day; // 31
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
      final isMarked = day == 21;
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
            'Marzo 2026 - 3:00 PM',
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
                Color(0xFFFFE08A), // Dorado brillante
                Color(0xFFD4AF37), // Gold clásico
                Color(0xFF8C6B1F), // Dorado oscuro profundo
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
                Color(0xFFFFE08A), // Dorado brillante
                Color(0xFFD4AF37), // Gold clásico
                Color(0xFF8C6B1F), // Dorado oscuro profundo
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
