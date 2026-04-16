// ignore_for_file: unused_field, unused_local_variable, dead_code

import 'dart:async';
import 'dart:ui_web' as ui; // For platformViewRegistry (web)
import 'dart:html' as html; // For IFrameElement (web)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:universal_html/html.dart' as html;

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
  // Cuenta regresiva estilo reloj (HH:MM:SS) hasta el 26 de abirl de 2026
  Timer? _countdownTimer;
  int _d = 0, _h = 0, _m = 0, _s = 0;
  bool _mapRegistered = false;

  bool _alreadyConfirmed = false;
  
  // Audio
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
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
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = AppConfig.eventDate.difference(DateTime.now());

      if (!mounted) return;

      setState(() {
        _d = diff.inDays;
        _h = diff.inHours % 24;
        _m = diff.inMinutes % 60;
        _s = diff.inSeconds % 60;
      });
    });
  }

  void _enviarWhatsApp(String nombre, String acompanante) async {
    if (nombre.isEmpty) {
      return;
    }
    final String mensaje = "Hola! Soy $nombre 🎉\nConfirmo que asistiré a la fiesta 🥳";

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
        "https://wa.me/573152611873?text=${Uri.encodeComponent(mensaje)}"; // cámbialo por tu número de WhatsApp
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
  
  // Nueva función de confirmación con datos de la ruta
  void _confirmarAsistenciaDesdeRuta() async {
    if (_guestDisplayNameFromRoute == null) return;
    
    bool _isConfirming = false;
    
    // Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Confirmar Asistencia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invitado: $_guestDisplayNameFromRoute'),
                _guestPassesFromRoute != null && _guestPassesFromRoute! > 1 
                    ? Text('Pases disponibles: $_guestPassesFromRoute') 
                    : Text('Pase disponible: $_guestPassesFromRoute'),
                SizedBox(height: 10),
                if (_isConfirming) ...[
                  SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text('Procesando confirmación...'),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isConfirming ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cerrar'),
              ),
              ElevatedButton(
                onPressed: _isConfirming ? null : () async {
                  setDialogState(() => _isConfirming = true);
                  
                  // Descontar pases automáticamente
                  try {
                    await SheetsService.confirm(_guestNameFromRoute!, consume: int.parse(_guestPassesFromRoute.toString()));
                    Navigator.of(ctx).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('¡Asistencia confirmada! ${_guestPassesFromRoute != null && _guestPassesFromRoute! > 1 ? 'pases descontados' : 'pase descontado'}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {
                      _alreadyConfirmed = true;
                    });
                    // Enviar WhatsApp después de confirmar
                    _enviarWhatsApp(_guestDisplayNameFromRoute!, "");
                  } catch (e) {
                    setDialogState(() => _isConfirming = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al confirmar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: _isConfirming 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Confirmar'),
              )
            ],
          );
        },
      ),
    );
  }

  // Nueva función para no confirmar asistencia
  void _noConfirmarAsistenciaDesdeRuta() async {
    if (_guestDisplayNameFromRoute == null) return;
    
    // Mostrar diálogo de confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('No Confirmar Asistencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitado: $_guestDisplayNameFromRoute'),
            Text('¿Estás seguro de que no podrás asistir a la fiesta?'),
            SizedBox(height: 10),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SheetsService.noConfirm(_guestNameFromRoute!, consume: _guestPassesFromRoute!);
                Navigator.of(ctx).pop(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('¡Gracias por informarnos! Te extrañaremos en la fiesta '),
                    backgroundColor: Colors.orange,
                  ),
                );
                setState(() {
                  _alreadyConfirmed = true; // Marcar como procesado
                  _guestPassesFromRoute = 0; // Actualizar pases a 0
                });
              } catch (e) {
                Navigator.of(ctx).pop(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al procesar: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('No Asistiré'),
          )
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

  Future<void> _tryAutoplayWeb() async {
    // Intenta reproducir en silencio y luego hacer fade-in
    try {
      await _player.setVolume(0.0);
      await _player.play(UrlSource('assets/lib/assets/audio/Blippi.mp3'));
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
        await _player.play(UrlSource('assets/lib/assets/audio/Blippi.mp3'));
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
          await _player.play(UrlSource('assets/lib/assets/audio/Blippi.mp3'));
        } else {
          if (_player.source == null) {
            await _player.play(UrlSource('assets/lib/assets/audio/Blippi.mp3'));
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

  Future<void> _restartMusic() async {
    try {
      // Detener cualquier reproducción anterior
      await _player.stop();
      
      // Reiniciar desde el principio según la plataforma
      if (kIsWeb) {
        await _player.setVolume(0.0);
        await _player.play(UrlSource('assets/lib/assets/audio/Blippi.mp3'));
        // Fade-in suave
        await _fadeInVolume(target: 1.0, steps: 10, totalDurationMs: 1200);
      } else {
        await _player.play(UrlSource('assets/lib/assets/audio/Blippi.mp3'));
      }
    } catch (e) {
      debugPrint('Restart music error: $e');
      // Si falla el reinicio, intentar el método normal
      if (kIsWeb) {
        _tryAutoplayWeb();
      } else {
        _startAudio();
      }
    }
  }

  Future<void> _startAudio() async {
    try {
      await _player.play(UrlSource('assets/lib/assets/audio/Blippi.mp3'));
      // _isPlaying se actualizará por el listener onPlayerStateChanged
    } catch (e) {
      debugPrint('Start audio error: $e');
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
    
    // Reiniciar música cada vez que se entra a la página
    _restartMusic();

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
        heroTag: "musicButton",
        onPressed: _togglePlayPause,
        backgroundColor: Color(0xFF001F54), // Azul navy
        elevation: 5,
        hoverElevation: 10,
        focusElevation: 10,
        highlightElevation: 10,
        hoverColor: Colors.white,
        tooltip: "Blippi - Canción Infantil",
        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.40),
              image: DecorationImage(
                image: AssetImage("lib/assets/4.jpg"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.40),
                  BlendMode.darken,
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 🔹 Sección 1
                  Container(
                    height:  size.width > 600 ? size.height * 2.1 : size.height * 0.5,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Contenido
                        Container(
                          margin: EdgeInsets.only(top: 50, left: 20, right: 20),
                          child: Image.asset("lib/assets/1.png"),
                          height: size.width > 600 ? size.height * 0.9 : size.height * 0.7,
                        ),
                        const SizedBox(height: 50),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20), 
                            FittedBox(
                              child: Text(
                                "¡Prepárate para una aventura increíble! 🚀",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.baloo2(
                                  fontSize: fontSizeTitle,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [
                                    Shadow(color: Colors.black,blurRadius: 8,offset: Offset(2.5, 2.5)),
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
                            "Falta para la fiesta 🎉:",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.ropaSans(
                              fontSize: size.width > 600 ? size.width * 0.03 : size.width * 0.06,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
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
                                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
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
                                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
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
                                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
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
                                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2)),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  // 🔹 Sección 2
                  Container(
                    height: size.width > 600 ? size.height * 1.8 : size.height * 0.8,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Calendario Abril 2026 con corazón en el 26
                            _buildCalendar(),
                            const SizedBox(height: 20),
                            Text(
                              "🎂 FIESTA DE CUMPLEAÑOS 🎂",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                fontSize: fontSizeTitle,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.celebration,
                                      color: Colors.white,
                                      size: 80,
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Salón de juegos Mega Park",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.baloo2(
                                            fontSize: fontSizeBody,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "2:30 PM",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.baloo2(
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
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        "Centro Comercial La Herradura",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.baloo2(
                                          fontSize: fontSizeBody,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 🔹 Sección 3
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        if (_soldOut || _guestPassesFromRoute == 0 )
                          Container(
                            width: size.width > 600 ? 480 : size.width * 0.85,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '¡Los cupos están a tope! 💥🎉\n\nYa casi comienza la celebración... ¡nos vemos pronto para vivir este día inolvidable! 🥳',
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
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '¡Hola soy $_guestDisplayNameFromRoute 🎉\nConfirmo que asistiré a la fiesta 🥳',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.baloo2(
                                      color: Colors.white,
                                      fontSize: fontSizeTitle,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  (!_alreadyConfirmed) ? Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: _confirmarAsistenciaDesdeRuta,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[900],
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                        ),
                                        child: const Text(
                                          "Sí, iré 🎉",
                                          style: TextStyle(fontSize: 14, color: Colors.white),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: _noConfirmarAsistenciaDesdeRuta,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[900],
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 15),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                        ),
                                        child: const Text(
                                          "No puedo ir 😔",
                                          style: TextStyle(fontSize: 14, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ) : Text(
                                    "Muchas gracias por responder.\nNos vemos pronto",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.baloo2(
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
          ),
        ],
      ),
    );
  }

  // 🔹 Calendario simple: Abril 2026 con corazón en el día 27
  Widget _buildCalendar() {
    final size = MediaQuery.of(context).size;
    final monthStart = DateTime(2026, 4, 1);
    final daysInMonth = DateTime(2026, 5, 0).day; // 31
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
      final isMarked = day == 26;
      return Container(
        margin: EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isMarked ? Colors.blue.withOpacity(0.5) : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.deepOrange),
        ),
        alignment: Alignment.center,
        child: day == null
            ? const SizedBox.shrink()
            : Stack(
              children: [
                if (isMarked)
                  Center(
                    child: Icon(
                      Icons.circle_outlined,
                      color: Colors.redAccent.shade700,
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
            'Abril 2026 - 2:30 PM',
            style: GoogleFonts.baloo2(
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
            width: size.width * 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                Color(0xFF0077FF), // azul
                Color(0xFFFF7A00), // naranja
                Color(0xFFFFD500), // amarillo
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: size.width * 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                Color(0xFF0077FF), // azul
                Color(0xFFFF7A00), // naranja
                Color(0xFFFFD500), // amarillo
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
class AppConfig {
  static final eventDate = DateTime(2026, 4, 26);

  static const primary = Color(0xFF0077FF);
  static const secondary = Color(0xFFFF7A00);
  static const accent = Color(0xFFFFD500);
}