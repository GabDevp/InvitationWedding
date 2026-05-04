import 'dart:async';
import 'dart:ui' as ui; // For platformViewRegistry (web)
import 'dart:html' as html; // For IFrameElement (web)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:invitacion_boda/widgets/carrusel.dart';
import 'package:invitacion_boda/services/sheets_services.dart';
import 'package:video_player/video_player.dart';

class InvitacionPage extends StatefulWidget {
  const InvitacionPage({super.key});

  @override
  State<InvitacionPage> createState() => _InvitacionPageState();
}

class _InvitacionPageState extends State<InvitacionPage>
    with TickerProviderStateMixin {
  // Cuenta regresiva estilo reloj (HH:MM:SS) hasta el 13 de diciembre de 2025
  Timer? _countdownTimer;
  int _d = 0, _h = 0, _m = 0, _s = 0;
  bool _mapRegistered = false;

  // Audio
  late final AudioPlayer _player;
  bool _isPlaying = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<html.Event>? _firstGestureSub;

  // Video
  late final VideoPlayerController _videoController;

  // Animación de aparición con scroll
  late final ScrollController _scrollController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // Animación para recepción (independiente)
  late final AnimationController _receptionFadeController;
  late final Animation<double> _receptionFadeAnimation;

  // Animación para carrusel (deslizamiento derecha a izquierda)
  late final AnimationController _carouselController;
  late final Animation<Offset> _carouselSlideAnimation;

  // Animación Dress Code (deslizamiento abajo a arriba)
  late final AnimationController _dressCodeController;
  late final Animation<Offset> _dressCodeSlideAnimation;

  // Animación Regalos (deslizamiento derecha a izquierda)
  late final AnimationController _regalosController;
  late final Animation<Offset> _regalosSlideAnimation;

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
  bool _isSearchingNames = false;
  // Control de búsqueda al seleccionar una sugerencia
  String? _selectedNameDisplay;
  String? _selectedNameKey;
  bool _ignoreNextNameChange = false;

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
    _selectedNameKey = null;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), _runNameSearch);
  }

  Future<void> _runNameSearch({Function()? setDialogState}) async {
    final raw = _nombreCtrl.text;
    final name = raw.trim();
    if (name.length < 2) {
      if (!mounted) return;
      setState(() {
        _nameSuggestions = [];
        _passesForTypedName = null;
        _isSearchingNames = false;
      });
      setDialogState?.call(); // Actualizar diálogo si está activo
      return;
    }

    if (!mounted) return;
    // Usar setState para variables globales y setDialogState para el diálogo
    setState(() {
      _isSearchingNames = true;
    });
    setDialogState?.call(); // Actualizar inmediatamente el diálogo

    try {
      final results = await SheetsService.search(name.toLowerCase());
      // results: List of maps with key_normalized, display, passesRemaining
      if (!mounted) return;
      setState(() {
        _nameSuggestions = results.cast<Map<String, dynamic>>();
        _isSearchingNames = false;
      });
      setDialogState?.call(); // Actualizar inmediatamente el diálogo
      // Si hay coincidencia exacta por display o por key, actualizar pases
      final nameLower = name.toLowerCase();
      final exact = _nameSuggestions.firstWhere(
        (e) =>
            ((e['display'] ?? '').toString().toLowerCase().trim()) == nameLower,
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
      if (mounted) {
        setState(() {
          _isSearchingNames = false;
        });
        setDialogState?.call(); // Actualizar diálogo incluso en caso de error
      }
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
      final target = DateTime(2026, 7, 18);
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
        "https://www.google.com/maps?vet=12ahUKEwipyfnhh7uSAxXkmbAFHYyRBMcQ8UF6BAgoEAI..i&lei=ZrqAaan-HeSzwt0PjKOSuAw&cs=1&um=1&ie=UTF-8&fb=1&gl=co&sa=X&geocode=KY_shlMAxTmOMbBiVo-qEDCw&daddr=Narino,+Palomestizo,+Tulu%C3%A1,+Valle+del+Cauca"; // cámbialo por tu ubicación real
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _enviarWhatsApp(String nombre, String acompanante) async {
    if (nombre.isEmpty) {
      return;
    }
    final String mensaje = acompanante.isEmpty
        ? "Hola! Soy $nombre y confirmo mi asistencia para asistir a este evento tan importante el día 18/07/26"
        : "Hola! Soy $nombre y confirmo mi asistencia con $acompanante para asistir a este evento tan importante el día 18/07/26";

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
        "https://wa.me/573164067016?text=${Uri.encodeComponent(mensaje)}"; // cámbialo por tu número de WhatsApp
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

// 🔹 Ciclo de vida y build (ajustado)
  @override
  void initState() {
    super.initState();
    if (kIsWeb && !_mapRegistered) {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory('gmap-iframe', (int viewId) {
        final iframe = html.IFrameElement()
          ..src =
              'https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3989.800881111111!2d-76.2290202!3d4.0894487!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x8e39c5005386ec8f%3A0xb03010aa8f5662b0!2sFinca%20Villa%20In%C3%A9s!5e0!3m2!1ses!2sco!4v1234567890123'
          ..style.border = '0'
          ..allowFullscreen = true;
        return iframe;
      });
      _mapRegistered = true;
    }
    // Inicializar ScrollController y animación
    _scrollController = ScrollController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Inicializar animación para recepción
    _receptionFadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _receptionFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _receptionFadeController, curve: Curves.easeOut),
    );

    // Inicializar animación para carrusel
    _carouselController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _carouselSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Empieza desde la derecha
      end: const Offset(0.0, 0.0), // Termina en el centro
    ).animate(CurvedAnimation(
      parent: _carouselController,
      curve: Curves.easeOutCubic,
    ));

    // Inicializar animación para DressCode
    _dressCodeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _dressCodeSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // Empieza desde abajo
      end: const Offset(0.0, 0.0), // Termina en el centro
    ).animate(CurvedAnimation(
      parent: _dressCodeController,
      curve: Curves.easeOutCubic,
    ));

    // Inicializar animación para Regalos
    _regalosController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _regalosSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Empieza desde la derecha
      end: const Offset(0.0, 0.0), // Termina en el centro
    ).animate(CurvedAnimation(
      parent: _regalosController,
      curve: Curves.easeOutCubic,
    ));

    // Escuchar cambios en el scroll
    _scrollController.addListener(() {
      final scrollPosition = _scrollController.offset;
      final ceremonyTrigger = 300.0; // Posición para ceremonia
      final receptionTrigger = 700.0; // Posición para recepción
      final carouselTrigger = 1700.0; // Posición para carrusel
      final dressCodeTrigger = 2700.0; // Posición para dress code
      final regalosTrigger = 3700.0; // Posición para regalos

      // Controlar animación de ceremonia
      if (scrollPosition > ceremonyTrigger && !_fadeController.isCompleted) {
        _fadeController.forward();
      } else if (scrollPosition <= ceremonyTrigger &&
          _fadeController.isCompleted) {
        _fadeController.reverse();
      }

      // Controlar animación de recepción
      if (scrollPosition > receptionTrigger &&
          !_receptionFadeController.isCompleted) {
        _receptionFadeController.forward();
      } else if (scrollPosition <= receptionTrigger &&
          _receptionFadeController.isCompleted) {
        _receptionFadeController.reverse();
      }

      // Controlar animación de carrusel
      if (scrollPosition > carouselTrigger &&
          !_carouselController.isCompleted) {
        _carouselController.forward();
      } else if (scrollPosition <= carouselTrigger &&
          _carouselController.isCompleted) {
        _carouselController.reverse();
      }

      // Controlar animación de dress code
      if (scrollPosition > dressCodeTrigger &&
          !_dressCodeController.isCompleted) {
        _dressCodeController.forward();
      } else if (scrollPosition <= dressCodeTrigger &&
          _dressCodeController.isCompleted) {
        _dressCodeController.reverse();
      }

      // Controlar animación de regalos
      if (scrollPosition > regalosTrigger && !_regalosController.isCompleted) {
        _regalosController.forward();
      } else if (scrollPosition <= regalosTrigger &&
          _regalosController.isCompleted) {
        _regalosController.reverse();
      }
    });

    _startCountdown();
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.loop);
    if (kIsWeb) {
      _tryAutoplayWeb();
    } else {
      _startAudio();
    }

    _videoController = VideoPlayerController.asset(
      'lib/assets/video/invitacion.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
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
    _scrollController.dispose();
    _fadeController.dispose();
    _receptionFadeController.dispose();
    _carouselController.dispose();
    _dressCodeController.dispose();
    _regalosController.dispose();
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

  Future<void> _fadeInVolume(
      {required double target,
      int steps = 8,
      int totalDurationMs = 800}) async {
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
          child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white),
        ),
        body: Container(
          // 🔹 Fondo único en toda la pantalla
          // if (_videoController.value.isInitialized)
          // SizedBox.expand(
          //   child: FittedBox(
          //     fit: BoxFit.cover,
          //     child: SizedBox(
          //       width: size.width,
          //       height: size.height,
          //       child: VideoPlayer(_videoController),
          //     ),
          //   ),
          // ),
          // else
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("lib/assets/4.jpeg"),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.30), BlendMode.darken),
            ),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                ),
                // 🔹 Sección 1 con su propio borde floral
                Stack(
                  children: [
                    Container(
                      height: size.height * 0.8,
                      child: Center(
                        child: Container(
                          height: size.width > 600
                              ? size.height * 2.1
                              : size.height * 0.4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 50),
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
                                          fontSize: size.width > 600
                                              ? size.width * 0.03
                                              : size.width * 0.06,
                                          color: const Color(0xFFB08D57),
                                          fontWeight: FontWeight.w600,
                                          shadows: const [
                                            Shadow(
                                                color: Colors.black54,
                                                blurRadius: 3,
                                                offset: Offset(1, 1)),
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
                                                '$_d|',
                                                style: GoogleFonts.robotoMono(
                                                  fontSize: size.width > 600
                                                      ? size.width * 0.05
                                                      : size.width * 0.10,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  shadows: const [
                                                    Shadow(
                                                        color: Colors.black54,
                                                        blurRadius: 2,
                                                        offset: Offset(2, 2)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Días',
                                              style: GoogleFonts.roboto(
                                                fontSize: size.width > 600
                                                    ? size.width * 0.02
                                                    : size.width * 0.04,
                                                color: const Color(0xFFB08D57),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                            width: size.width > 600 ? 24 : 10),
                                        // Horas
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FittedBox(
                                              child: Text(
                                                '${_h.toString().padLeft(2, '0')}|',
                                                style: GoogleFonts.robotoMono(
                                                  fontSize: size.width > 600
                                                      ? size.width * 0.05
                                                      : size.width * 0.10,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  shadows: const [
                                                    Shadow(
                                                        color: Colors.black54,
                                                        blurRadius: 2,
                                                        offset: Offset(2, 2)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Horas',
                                              style: GoogleFonts.roboto(
                                                fontSize: size.width > 600
                                                    ? size.width * 0.02
                                                    : size.width * 0.04,
                                                color: const Color(0xFFB08D57),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                            width: size.width > 600 ? 24 : 10),
                                        // Minutos
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FittedBox(
                                              child: Text(
                                                '${_m.toString().padLeft(2, '0')}|',
                                                style: GoogleFonts.robotoMono(
                                                  fontSize: size.width > 600
                                                      ? size.width * 0.05
                                                      : size.width * 0.10,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  shadows: const [
                                                    Shadow(
                                                        color: Colors.black54,
                                                        blurRadius: 2,
                                                        offset: Offset(2, 2)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Minutos',
                                              style: GoogleFonts.roboto(
                                                fontSize: size.width > 600
                                                    ? size.width * 0.02
                                                    : size.width * 0.04,
                                                color: const Color(0xFFB08D57),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                            width: size.width > 600 ? 24 : 10),
                                        // Segundos
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FittedBox(
                                              child: Text(
                                                _s.toString().padLeft(2, '0'),
                                                style: GoogleFonts.robotoMono(
                                                  fontSize: size.width > 600
                                                      ? size.width * 0.05
                                                      : size.width * 0.10,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  shadows: const [
                                                    Shadow(
                                                        color: Colors.black54,
                                                        blurRadius: 2,
                                                        offset: Offset(2, 2)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Segundos',
                                              style: GoogleFonts.roboto(
                                                fontSize: size.width > 600
                                                    ? size.width * 0.02
                                                    : size.width * 0.04,
                                                color: const Color(0xFFB08D57),
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
                                          fontSize: size.width > 600
                                              ? size.width * 0.03
                                              : size.width * 0.055,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          shadows: const [
                                            Shadow(
                                                color: Colors.black54,
                                                blurRadius: 3,
                                                offset: Offset(1, 1)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Borde floral para sección 1
                    Positioned(
                      top: 75,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Borde floral inferior
                    Positioned(
                      bottom: 95,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                // 🔹 Sección 2 con su propio borde floral
                Container(
                  height:
                      size.width > 600 ? size.height * 4.2 : size.height * 1.8,
                  width: double.infinity,
                  child: Center(
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeInOut,
                            height: size.height * 0.5,
                            width: size.width * 0.8,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // PNG de anillos
                                Container(
                                  width: size.width * 0.3,
                                  height: size.height * 0.12,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.asset(
                                      'lib/assets/anillos.png', // Asumiendo que tienes esta imagen
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                // Título CEREMONIA
                                Text(
                                  "CEREMONIA",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB08D57),
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Divider dorado
                                Container(
                                  width: size.width * 0.6,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB08D57),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                // Subtitulo del mes
                                Text(
                                  "Julio",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 20,
                                    color: const Color(0xFFB08D57),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Día, hora y día de semana
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Hora a la izquierda
                                    Text(
                                      "4:00 PM",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 18,
                                        color: const Color(0xFFB08D57),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(width: 30),
                                    // Día del mes centrado
                                    Text(
                                      "18",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 40,
                                        color: const Color(0xFFB08D57),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 30),
                                    // Día de semana a la derecha
                                    Text(
                                      "Sábado",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 22,
                                        color: const Color(0xFFB08D57),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Año centrado
                                Text(
                                  "2026",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    color: const Color(0xFFB08D57),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Lugar
                                Text(
                                  "Villa Inés",
                                  style: GoogleFonts.dancingScript(
                                    fontSize: 28,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 50,
                        ),
                        FadeTransition(
                          opacity: _receptionFadeAnimation,
                          child: Container(
                            height: size.height * 1.0,
                            width: size.width * 0.8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // PNG de copas
                                    Container(
                                      width: size.width * 0.3,
                                      height: size.height * 0.12,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.asset(
                                          'lib/assets/copas.png', // Asumiendo que tienes esta imagen
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    // Título RECEPCIÓN
                                    Text(
                                      "RECEPCIÓN",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFB08D57),
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Divider dorado
                                    Container(
                                      width: size.width,
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB08D57),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    // Subtitulo del mes
                                    Text(
                                      "Julio",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 20,
                                        color: const Color(0xFFB08D57),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Día, hora y día de semana
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        // Día de semana a la izquierda
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Sábado",
                                              style:
                                                  GoogleFonts.playfairDisplay(
                                                fontSize: 22,
                                                color: const Color(0xFFB08D57),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Divider dorado debajo del texto
                                            Container(
                                              width: 95,
                                              height: 2,
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                    255, 132, 106, 66),
                                                borderRadius:
                                                    BorderRadius.circular(1),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 20),
                                        // Día del mes centrado
                                        Text(
                                          "18",
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 40,
                                            color: const Color(0xFFB08D57),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        // Hora a la derecha
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              "5:30 PM",
                                              style:
                                                  GoogleFonts.playfairDisplay(
                                                fontSize: 18,
                                                color: const Color(0xFFB08D57),
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Divider dorado debajo del texto
                                            Container(
                                              width: 95,
                                              height: 2,
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                    255, 132, 106, 66),
                                                borderRadius:
                                                    BorderRadius.circular(1),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Año centrado
                                    Text(
                                      "2026",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 24,
                                        color: const Color(0xFFB08D57),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Lugar
                                    Text(
                                      "Villa Inés",
                                      style: GoogleFonts.dancingScript(
                                        fontSize: 28,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: size.width > 600
                                            ? size.width * 0.6
                                            : size.width * 0.85,
                                        height: 320,
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.white24),
                                        ),
                                        child: const HtmlElementView(
                                            viewType: 'gmap-iframe'),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    ElevatedButton(
                                      onPressed: _abrirGoogleMaps,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFB08D57),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                      ),
                                      child: const Text("Ver en Google Maps",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 🔹 Sección 3 con su propio borde floral para la galeria de fotos
                Stack(
                  children: [
                    Container(
                      height: size.height * 1.2,
                      width: double.infinity,
                      child: Center(
                        child: SlideTransition(
                          position: _carouselSlideAnimation,
                          child: Container(
                            height: size.height * 0.9,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "RETRATOS DE NUESTRO AMOR",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB08D57),
                                  ),
                                ),
                                Text(
                                  "La clave esta en disfrutar cada momento",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Carrusel más centrado y uniforme
                                CarruselConDots(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Borde floral superior para sección 3
                    Positioned(
                      top: 55,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Borde floral inferior para sección 3
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 55,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Seccion 4 calendario mas tarjetas de vestimenta y información adicional
                Container(
                  height:
                      size.width > 600 ? size.height * 4.2 : size.height * 1.6,
                  width: double.infinity,
                  child: Center(
                    child: Column(
                      children: [
                        // Calendario Julio 2026 con corazón en el 18
                        _buildCalendar(),
                        const SizedBox(height: 50),
                        // Tarjeta 1: Dress Code con Flip Card
                        SlideTransition(
                          position: _dressCodeSlideAnimation,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeInOut,
                            height: size.height * 0.5 + 0.008,
                            width: size.width * 0.8,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 12),
                                // Título DRESS CODE
                                Text(
                                  "DRESS CODE",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB08D57),
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // PNG del moño/corbatín
                                Container(
                                  width: size.width * 0.3,
                                  height: size.height * 0.12,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.asset(
                                      'lib/assets/corbatin.png', // Asumiendo que tienes esta imagen
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                // Subtítulo
                                Text(
                                  "Elegante Formal",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 20,
                                    color: const Color(0xFFB08D57),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Contenido
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: size.width * 0.1),
                                  child: Text(
                                    "Una orientacion para ver tu vestimenta para verte elegante y formal para celebrar nuestro amor. 💕",
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                // Botón Dress Code
                                ElevatedButton(
                                  onPressed: () =>
                                      _showDressCodeDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB08D57),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 25, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    "Ver Dress Code",
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Tarjeta 2: Regalo con Flip Card inverso
                        SlideTransition(
                          position: _dressCodeSlideAnimation,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeInOut,
                            height: size.height * 0.5,
                            width: size.width * 0.8,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 12),
                                // Título DRESS CODE
                                Text(
                                  "TIPS Y NOTAS",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB08D57),
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // PNG del moño/corbatín
                                Container(
                                  width: size.width * 0.3,
                                  height: size.height * 0.12,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.asset(
                                      'lib/assets/tips.png', // Asumiendo que tienes esta imagen
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                // Subtítulo
                                Text(
                                  "Informaciones",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 20,
                                    color: const Color(0xFFB08D57),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Contenido
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: size.width * 0.1),
                                  child: Text(
                                    "Conoce unas recomendaciones personales que esperamos de tu parte 🤗",
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                // Botón Dress Code
                                ElevatedButton(
                                  onPressed: () =>
                                      _showRecomendacionesDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB08D57),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 25, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    "Ver Info.",
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Seccion 5 regalos
                Stack(
                  children: [
                    Container(
                      height: size.width > 600
                          ? size.height * 4.2
                          : size.height * 0.7,
                      width: double.infinity,
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 70),
                            // Tarjeta 3: Regalos
                            SlideTransition(
                              position: _regalosSlideAnimation,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeInOut,
                                height: size.height * 0.5 + 0.008,
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 12),
                                    // Título REGALOS
                                    Text(
                                      "REGALOS",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFB08D57),
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    // PNG del regalo
                                    Container(
                                      width: size.width * 0.3,
                                      height: size.height * 0.12,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.asset(
                                          'lib/assets/regalo.gif', // Asumiendo que tienes esta imagen
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    // Subtítulo
                                    Text(
                                      "Lluvia de Sobres",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 20,
                                        color: const Color(0xFFB08D57),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Contenido
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: size.width * 0.1),
                                      child: Text(
                                        "Tu presencia es el mejor regalo. Si deseas honrarnos con un detalle, agradecemos un veas estas opciones",
                                        style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    // Botón Regalos
                                    ElevatedButton(
                                      onPressed: () =>
                                          _showRegalosDialog(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFB08D57),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 25, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text(
                                        "Ver Información",
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Borde floral superior para sección 5
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Borde floral inferior para sección 5
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 25,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Seccion 6 QR de albumn
                Stack(
                  children: [
                    Container(
                      height: size.width > 600
                          ? size.height * 4.2
                          : size.height * 0.8 + 0.005,
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          width: size.width * 0.7 + 0.005,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Título ALBUMN
                              Text(
                                "COMPARTIMOS ESTE DÍA JUNTO A TI",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // Subtítulo
                              Text(
                                "Comparte tus fotos y videos de este hermoso momento",
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 15),
                              // PNG del QR
                              Container(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.asset(
                                    'lib/assets/qrphotos.jpeg', // Asumiendo que tienes esta imagen
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Contenido
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: size.width * 0.1),
                                child: Text(
                                  "Escanea el QR y sube tus fotos.",
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ), // Borde floral inferior para sección 5
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -40,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Seccion 7 Tarjeta de Confirmación
                Stack(
                  children: [
                    Container(
                      height: size.width > 600 ? size.height * 4.2 : size.height * 0.7,
                      width: double.infinity,
                      child: Center(
                        child: Column(
                          children: [
                            // Tarjeta de Confirmación
                            SlideTransition(
                              position: _regalosSlideAnimation,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeInOut,
                                height: size.height * 0.6,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 20),
                                    // Título CONFIRMAR ASISTENCIA
                                    Text(
                                      "CONFIRMAR ASISTENCIA",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFB08D57),
                                        letterSpacing: 3,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    // Icono de confirmación
                                    Container(
                                      width: size.width * 0.2,
                                      height: size.height * 0.1,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB08D57)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outline,
                                        size: 50,
                                        color: Color(0xFFB08D57),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // Subtítulo
                                    Text(
                                      "Confirma tu asistencia",
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 20,
                                        color: const Color(0xFFB08D57),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 15),
                                    // Contenido
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: size.width * 0.1),
                                      child: Text(
                                        "Por favor confirma tu asistencia para que podamos prepararlo todo para ti. ¡Te esperamos! 💕",
                                        style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 25),
                                    // Botón Confirmar Asistencia
                                    ElevatedButton(
                                      onPressed: () =>
                                          _showConfirmacionDialog(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFB08D57),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 30, vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: const Text(
                                        "Confirmar Asistencia",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                                  // Aviso de plazo de confirmación
                                  Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          color: Colors.red[700],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "El plazo para confirmar es hasta el 30 de junio",
                                            style: GoogleFonts.nunito(
                                              fontSize: 14,
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            )
                          ],
                        ),
                      ),
                    ),
                    // Borde floral inferior para sección 7
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 25,
                      child: Container(
                        height: size.height * 0.15,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('lib/assets/flores.png'),
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            repeat: ImageRepeat.repeatX,
                            scale: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }

  // Función de búsqueda optimizada para diálogo
  void _onNameChangedInDialog(
      void Function(void Function() fn) setDialogState) {
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
    _selectedNameKey = null;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      _runNameSearch(setDialogState: () => setDialogState(() {}));
    });
  }

  // Metodo para mostrar diálogo de confirmación
  void _showConfirmacionDialog(BuildContext context) {
    bool _isConfirt = false;
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              child: Container(
                height: size.height * 0.8,
                width: size.width,
                decoration: BoxDecoration(
                  color: const Color(0xFFB08D57),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 30),
                  child: Container(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    margin: const EdgeInsets.only(left: 10, right: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 20),
                        // Título
                        Text(
                          "¿Asistes a la celebración?",
                          style: GoogleFonts.playfairDisplay(
                            fontSize: size.width * 0.05,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Radio button SÍ
                            Row(
                              children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: _isConfirt,
                                  activeColor: Colors.white,
                                  fillColor: MaterialStateProperty.resolveWith(
                                      (states) {
                                    if (states
                                        .contains(MaterialState.selected)) {
                                      return Colors.white;
                                    }
                                    return Colors.white.withOpacity(0.7);
                                  }),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _isConfirt = value ?? false;
                                    });
                                  },
                                ),
                                Text(
                                  "¡Sí, confirmo!",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _isConfirt == true
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            // Radio button NO
                            Row(
                              children: [
                                Radio<bool>(
                                  value: false,
                                  groupValue: _isConfirt,
                                  activeColor: Colors.white,
                                  fillColor: MaterialStateProperty.resolveWith(
                                      (states) {
                                    if (states
                                        .contains(MaterialState.selected)) {
                                      return Colors.white;
                                    }
                                    return Colors.white.withOpacity(0.7);
                                  }),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _isConfirt = value ?? false;
                                    });
                                  },
                                ),
                                Text(
                                  "No puedo 😔",
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _isConfirt == false
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Formulario
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (_soldOut)
                                  Container(
                                    width: double.infinity,
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    children: [
                                      // Campo nombre
                                      SizedBox(
                                        width: double.infinity,
                                        child: TextField(
                                          controller: _nombreCtrl,
                                          onChanged: (value) {
                                            // Usar función optimizada para diálogo
                                            _onNameChangedInDialog(
                                                (fn) => setDialogState(fn));
                                          },
                                          decoration: const InputDecoration(
                                            labelText: "Tu nombre",
                                            filled: true,
                                            fillColor: Colors.white70,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      // Sugerencias de nombre o estado de carga
                                      if (_nombreCtrl.text.trim().length >= 2 && _selectedNameDisplay == null)
                                      Container(
                                        width: double.infinity,
                                        constraints: const BoxConstraints(
                                            maxHeight: 120),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: const [
                                            BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 6,
                                                offset: Offset(0, 2)),
                                          ],
                                        ),
                                        child: _isSearchingNames
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 30,
                                                height: 30,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          const Color(
                                                              0xFFB08D57)),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Buscando invitados...",
                                                style: GoogleFonts.roboto(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                                textAlign:
                                                    TextAlign.center,
                                              ),
                                            ],
                                          )
                                        : _nameSuggestions.isEmpty && !_isSearchingNames && _nombreCtrl.text.trim().length >= 2
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .center,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .sentiment_very_dissatisfied,
                                                  size: 40,
                                                  color:
                                                      Colors.grey[600],
                                                ),
                                                const SizedBox(
                                                    height: 8),
                                                Text(
                                                  "No estás entre los invitados 😔",
                                                  style: GoogleFonts
                                                      .roboto(
                                                    color: Colors
                                                        .grey[600],
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                  textAlign:
                                                      TextAlign.center,
                                                ),
                                                const SizedBox(
                                                    height: 4),
                                                Text(
                                                  "Verifica el nombre exacto en tu invitación",
                                                  style: GoogleFonts
                                                      .roboto(
                                                    color: Colors
                                                        .grey[500],
                                                    fontSize: 12,
                                                  ),
                                                  textAlign:
                                                      TextAlign.center,
                                                ),
                                              ],
                                            )
                                          : ListView.builder(
                                              itemCount:
                                                  _nameSuggestions
                                                      .length,
                                              itemBuilder:
                                                  (context, index) {
                                                final item =
                                                    _nameSuggestions[
                                                        index];
                                                final display =
                                                    (item['display'] ??
                                                            '')
                                                        .toString();
                                                final nameKey = (item['key_normalized']).toString();
                                                final passesRem = int.tryParse(
                                                    item['passesRemaining']
                                                            ?.toString() ??
                                                        '');
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(display),
                                                  onTap: () {
                                                    setState(() {
                                                      _ignoreNextNameChange = true;
                                                      _selectedNameDisplay =
                                                          display;
                                                      _selectedNameKey = nameKey;
                                                      _nombreCtrl.text =
                                                          display;
                                                      _nombreCtrl
                                                              .selection =
                                                          TextSelection
                                                              .collapsed(
                                                                  offset:
                                                                      display.length);
                                                      _passesForTypedName =
                                                          passesRem;
                                                      _nameSuggestions =
                                                          [];
                                                      if ((passesRem ??
                                                              0) <
                                                          2)
                                                        _acompananteCtrl
                                                            .clear();
                                                    });
                                                    // Actualizar el diálogo para mostrar los campos de acompañantes
                                                    setDialogState(
                                                        () {});
                                                  },
                                                );
                                              },
                                            ),
                                        ),
                                      const SizedBox(height: 8),
                                      // Info de pases
                                      if (_passesForTypedName != null)
                                        SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            _passesForTypedName! > 1
                                                ? 'Tienes ${_passesForTypedName} pases disponibles, el tuyo y el de ${((_passesForTypedName ?? 1) - 1).clamp(0, 3)} acompañante.\nSi llevas niños es un pase para ellos tambien.'
                                                : 'El pase es solo para ti.',
                                            style: GoogleFonts.roboto(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      // Campos de acompañantes (solo si selecciona SÍ)
                                      if (!_soldOut && _isConfirt == true)
                                        ...(() {
                                          final p = _passesForTypedName ?? 0;
                                          final maxCompanions =
                                              (p - 1).clamp(0, 3);
                                          final widgets = <Widget>[];
                                          if (maxCompanions >= 1) {
                                            widgets.add(SizedBox(
                                              width: double.infinity,
                                              child: TextField(
                                                controller: _acompananteCtrl,
                                                style: const TextStyle(
                                                    color: Colors.black87),
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: "Acompañante 1",
                                                  filled: true,
                                                  fillColor: Colors.white70,
                                                  labelStyle: TextStyle(
                                                      color: Color(0xFFB08D57)),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(8)),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                ),
                                              ),
                                            ));
                                            widgets
                                                .add(const SizedBox(height: 8));
                                          }
                                          if (maxCompanions >= 2) {
                                            widgets.add(SizedBox(
                                              width: double.infinity,
                                              child: TextField(
                                                controller: _acompanante2Ctrl,
                                                style: const TextStyle(
                                                    color: Colors.black87),
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: "Acompañante 2",
                                                  filled: true,
                                                  fillColor: Colors.white70,
                                                ),
                                              ),
                                            ));
                                            widgets
                                                .add(const SizedBox(height: 8));
                                          }
                                          if (maxCompanions >= 3) {
                                            widgets.add(SizedBox(
                                              width: double.infinity,
                                              child: TextField(
                                                controller: _acompanante3Ctrl,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: "Acompañante 3",
                                                  filled: true,
                                                  fillColor: Colors.white70,
                                                ),
                                              ),
                                            ));
                                          }
                                          return widgets;
                                        }()),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Botones
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Botón cancelar
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.9),
                                foregroundColor: const Color(0xFFB08D57),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                "Cancelar",
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Botón confirmar
                            if (!_soldOut)
                              ElevatedButton(
                                onPressed: _isConfirming
                                    ? null
                                    : () async {
                                        final nombre = _nombreCtrl.text.trim();
                                        final key = _selectedNameKey;
                                        final acomp1 = _acompananteCtrl.text.trim();
                                        final acomp2 = _acompanante2Ctrl.text.trim();
                                        final acomp3 = _acompanante3Ctrl.text.trim();
                                        
                                        setState(() => _isConfirming = true);
                                        try {
                                          // Consultar invitado en Sheets
                                          final guest = await SheetsService.getGuest(key!);
                                          if (guest == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('No encontramos tu nombre. Escríbelo exactamente como aparece en la invitación.'),
                                                duration: Duration(seconds: 2),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          final passes = int.tryParse(guest['passesRemaining'] ?.toString() ?? '0') ?? 0;
                                          if (_isConfirt == true) {
                                            // CASO: CONFIRMAR ASISTENCIA
                                            if (passes <= 0) {
                                              await _refreshSoldOutFromSheets();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Ya no quedan pases disponibles para este nombre.'),
                                                  duration: Duration(seconds: 2),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            // Consumir pases considerando hasta 3 acompañantes
                                            final companionsInput = [
                                              acomp1,
                                              acomp2,
                                              acomp3
                                            ].where((s) => s.isNotEmpty).toList();
                                            int desired = 1 + companionsInput.length; // invitado + acompañantes
                                            if (desired > passes) {
                                              // recortar acompañantes a los cupos disponibles
                                              final allowedCompanions = (passes - 1).clamp(0, 3);
                                              companionsInput.removeRange(
                                                allowedCompanions,
                                                companionsInput.length);
                                              desired = 1 + companionsInput.length;
                                            }
                                            final updated = await SheetsService.confirm(key, consume: desired);
                                            if (updated == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('No se pudo confirmar. Intenta de nuevo.'),
                                                  duration: Duration(seconds: 2),
                                                  backgroundColor: Colors.red,
                                                ),
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

                                            // Cerrar diálogo después de confirmar
                                            Navigator.of(context).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('¡Asistencia confirmada! Te esperamos 💕'),
                                                duration: Duration(seconds: 3),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            // CASO: DECLINE ASISTENCIA
                                            final updated = await SheetsService.decline(
                                                key, 
                                                consume: passes
                                            );
                                            if (updated == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('No se pudo procesar tu respuesta. Intenta de nuevo.'),
                                                  duration: Duration(seconds: 2),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            // Cerrar diálogo después de procesar decline
                                            Navigator.of(context).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('¡Gracias por informarnos! Te extrañaremos en la fiesta 😔'),
                                                duration: Duration(seconds: 3),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (mounted)
                                            setState(() => _isConfirming = false);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: _isConfirming
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  )
                                : const Text(
                                    "Confirmar",
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                              ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  //🔹 Metodo para mostrar solo Dress Code
  void _showDressCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: size.width * 0.9,
            decoration: BoxDecoration(
              color: const Color(0xFFB08D57),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título
                  Text(
                    "Código de Vestimenta 👗🤵",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: size.width * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Descripción
                  Text(
                    "Hombres: Camisa - Pantalon 👔\nMujeres: Vestido 👗",
                    style: GoogleFonts.nunito(
                      fontSize: size.width * 0.04,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  // Advertencia
                  Text(
                    "Los colores son de muestra pero el\nCOLOR BLANCO RESERVADO PARA LA NOVIA",
                    style: GoogleFonts.nunito(
                      fontSize: size.width * 0.035,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Imágenes de hombres y mujeres
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            "Hombres",
                            style: GoogleFonts.nunito(
                              fontSize: size.width * 0.04,
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
                              fontSize: size.width * 0.04,
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
                  const SizedBox(height: 20),
                  // Botón cerrar
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8C6B1F),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
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

  //🔹 Metodo para mostrar información de Regalos
  void _showRegalosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: size.width * 0.9,
            decoration: BoxDecoration(
              color: const Color(0xFFB08D57),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono de regalo
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      size: 35,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Título
                  Text(
                    "Lluvia de Sobres 💌",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: size.width * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  // Mensaje principal
                  Text(
                    "Tu presencia es nuestro mayor regalo 💕",
                    style: GoogleFonts.playfairDisplay(
                      fontSize: size.width * 0.04,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  // Descripción mejorada
                  Text(
                    "Si además deseas honrarnos con un detalle, agradecemos tu contribución\na través de una lluvia de sobres o una transferencia.",
                    style: GoogleFonts.nunito(
                      fontSize: size.width * 0.040,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Información bancaria
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "🏦 Para Transferencias",
                          style: GoogleFonts.playfairDisplay(
                            fontSize: size.width * 0.038,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Banco: NU\nLlave Bre-B: 1116281304",
                          style: GoogleFonts.nunito(
                            fontSize: size.width * 0.034,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Nota de agradecimiento
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      "💕 Con todo nuestro cariño y gratitud\npor ser parte de este día tan especial",
                      style: GoogleFonts.nunito(
                        fontSize: size.width * 0.036,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Botón cerrar
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB08D57),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text("Gracias"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                    title: "¡Llega a tiempo! ⏰",
                    description: "Cada momento es creado con amor y queremos que vivas\nla experiencia completa desde el inicio,\npor eso llega puntual a la hora.",
                  ),
                  _buildRecommendationItem(context,
                      number: "2",
                      title: "Disfruta y baila 💃",
                      description: "Este día está hecho para celebrar, compartir y crear recuerdos que\ndurarán para siempre por eso \nqueremos que disfrutes de esta fiesta al máximo"),
                  _buildRecommendationItem(
                    context,
                    number: "3",
                    title: "Confirmar asistencia ✅",
                    description: "Por favor confirma tu asistencia antes del\n30 de Junio para que podamos coordinar todo a la perfección.",
                  ),
                  _buildRecommendationItem(
                    context,
                    number: "4",
                    title: "ATENCIÓN IMPORTANTE‼️",
                    description: "NO SE ACEPTARÁ LA ENTRADA DE LICOR.",
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8C6B1F),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 12),
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

  Widget _buildRecommendationItem(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
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
                TextSpan(
                  text: description,
                  style: GoogleFonts.nunito(
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Calendario simple: Julio 2026 con corazón en el día 18
  Widget _buildCalendar() {
    final size = MediaQuery.of(context).size;
    final monthStart = DateTime(2026, 7, 1);
    final daysInMonth = DateTime(2026, 8, 0).day; // 31
    final startWeekday = monthStart.weekday; // 1=Lun ... 7=Dom

    final leadingEmpty = startWeekday - 1; // celdas vacías antes del 1
    final cells = leadingEmpty + daysInMonth;
    final totalCells = ((cells + 6) ~/ 7) * 7; // múltiplo de 7

    TextStyle headerStyle = GoogleFonts.roboto(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: size.width > 600 ? 14 : 10,
      shadows: const [
        Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))
      ],
    );

    TextStyle dayStyle = GoogleFonts.roboto(
      color: Colors.white,
      fontWeight: FontWeight.w500,
      fontSize: size.width > 600 ? 16 : 12,
      shadows: const [
        Shadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))
      ],
    );

    Widget dayCell(int? day) {
      final isMarked = day == 18;
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isMarked
              ? Colors.amber.withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
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
            'Julio 2026 - 4:00 PM',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: size.width > 600 ? 28 : 22,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(
                    color: Colors.black54, blurRadius: 3, offset: Offset(2, 2))
              ],
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
}
