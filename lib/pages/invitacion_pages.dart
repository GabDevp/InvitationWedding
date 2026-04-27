import 'dart:async';
import 'dart:ui_web' as ui; // For platformViewRegistry (web)
import 'dart:html' as html; // For IFrameElement (web)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:invitacion_boda/widgets/countdownwidget.dart';
import 'package:invitacion_boda/widgets/titleanimated.dart';
import 'package:invitacion_boda/services/sheets_services.dart';
import 'package:invitacion_boda/widgets/form.dart';

class InvitacionPage extends StatefulWidget {
  final String? guestName;
  final String? guestDisplayName;
  final int? guestPasses;
  final int? guestConfirmedCount;
  const InvitacionPage({super.key, this.guestName, this.guestDisplayName, this.guestPasses, this.guestConfirmedCount});

  @override
  State<InvitacionPage> createState() => _InvitacionPageState();
}
class _InvitacionPageState extends State<InvitacionPage> with TickerProviderStateMixin {
  // Cuenta regresiva estilo reloj (HH:MM:SS) hasta el 13 de diciembre de 2025
  Timer? _countdownTimer;
  int _d = 0, _h = 0, _m = 0, _s = 0;
  bool _mapRegistered = false;

  bool _alreadyConfirmed = false;
  
  // Datos desde EnvelopePage
  int? _guestConfirmedCountFromRoute;
  
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
  final TextEditingController _acompanante4Ctrl = TextEditingController();
  final TextEditingController _acompanante5Ctrl = TextEditingController();
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
              _acompanante4Ctrl.clear();
              _acompanante5Ctrl.clear();
            } else if (pp == 2) {
              _acompanante2Ctrl.clear();
              _acompanante3Ctrl.clear();
              _acompanante4Ctrl.clear();
              _acompanante5Ctrl.clear();
            } else if (pp == 3) {
              _acompanante3Ctrl.clear();
              _acompanante4Ctrl.clear();
              _acompanante5Ctrl.clear();
            } else if (pp == 4){
              _acompanante4Ctrl.clear();
              _acompanante5Ctrl.clear();
            } else if (pp == 5){
              _acompanante5Ctrl.clear();
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
            _acompanante4Ctrl.clear();
            _acompanante5Ctrl.clear();
          });
        }
      }
    } catch (e) {
      debugPrint('Name search error: $e');
    }
  }

  Future<void> _refreshSoldOutFromSheets() async {
    try {
      // Si viene desde EnvelopePage con confirmedCount, usar ese valor
      if (_guestConfirmedCountFromRoute != null) {
        if (mounted) setState(() => _soldOut = _guestConfirmedCountFromRoute != 0);
        return;
      }
    } catch (_) {}
  }

  Future<void> _askToAttendDialog() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa tu nombre primero.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? deseaAsistir = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('¿Deseas asistir a la fiesta?', 
          style: GoogleFonts.playfairDisplay(fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola $nombre,', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Nos encantaría que vengas a celebrar con nosotros. Si deseas asistir, por favor indícanos quiénes vendrán.', 
              style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            const Text('¿Te gustaría asistir?', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, gracias'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Sí, deseo asistir'),
          ),
        ],
      ),
    );

    if (deseaAsistir == true) {
      await _showAttendanceForm();
    } else if (deseaAsistir == false) {
      await _declineInvitation();
    }
  }

  Future<void> _showAttendanceForm() async {
    final nombre = _nombreCtrl.text.trim();
    
    // Limpiar campos de acompañantes
    _acompananteCtrl.clear();
    _acompanante2Ctrl.clear();
    _acompanante3Ctrl.clear();
    _acompanante4Ctrl.clear();
    _acompanante5Ctrl.clear();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final TextEditingController localAcomp1 = TextEditingController();
          final TextEditingController localAcomp2 = TextEditingController();
          final TextEditingController localAcomp3 = TextEditingController();
          final TextEditingController localAcomp4 = TextEditingController();
          final TextEditingController localAcomp5 = TextEditingController();
          
          return AlertDialog(
            title: Text('¿Quiénes asistirán?', 
              style: GoogleFonts.playfairDisplay(fontSize: 22)),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hola $nombre, por favor indícanos quiénes vendrán:', 
                    style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: localAcomp1,
                    decoration: const InputDecoration(
                      labelText: 'Acompañante 1 (opcional)',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: localAcomp2,
                    decoration: const InputDecoration(
                      labelText: 'Acompañante 2 (opcional)',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: localAcomp3,
                    decoration: const InputDecoration(
                      labelText: 'Acompañante 3 (opcional)',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: localAcomp4,
                    decoration: const InputDecoration(
                      labelText: 'Acompañante 4 (opcional)',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: localAcomp5,
                    decoration: const InputDecoration(
                      labelText: 'Acompañante 5 (opcional)',
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final companions = [
                    localAcomp1.text.trim(),
                    localAcomp2.text.trim(),
                    localAcomp3.text.trim(),
                    localAcomp4.text.trim(),
                    localAcomp5.text.trim(),
                  ].where((e) => e.isNotEmpty).toList();
                  
                  Navigator.of(ctx).pop({
                    'nombre': nombre,
                    'acompanantes': companions,
                    'total': 1 + companions.length,
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Enviar solicitud'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await _processAttendanceRequest(result);
    }
  }

  Future<void> _processAttendanceRequest(Map<String, dynamic> data) async {
    setState(() => _isConfirming = true);
    
    try {
      final nombre = data['nombre'] as String;
      final total = data['total'] as int;
      
      // Aquí podrías agregar lógica para enviar un email o notificación
      // Por ahora, mostramos un mensaje de confirmación
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Gracias $nombre! Hemos recibido tu solicitud para $total personas.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // Enviar WhatsApp automáticamente
      _enviarWhatsApp(nombre, total.toString());
      
      // Limpiar formulario
      _nombreCtrl.clear();
      _acompananteCtrl.clear();
      _acompanante2Ctrl.clear();
      _acompanante3Ctrl.clear();
      _acompanante4Ctrl.clear();
      _acompanante5Ctrl.clear();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar solicitud: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Future<void> _declineInvitation() async {
    final nombre = _nombreCtrl.text.trim();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Entendido $nombre. Te extrañaremos, ¡esperamos verte pronto!'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Limpiar formulario
    _nombreCtrl.clear();
    _acompananteCtrl.clear();
    _acompanante2Ctrl.clear();
    _acompanante3Ctrl.clear();
    _acompanante4Ctrl.clear();
    _acompanante5Ctrl.clear();
  }

  void _startCountdown() {
    void calc() {
      final now = DateTime.now();
      final target = DateTime(2026, 5, 17);
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
        "https://www.google.com/maps/place/Sede+Comunal+Los+Guayacanes/@3.4743975,-76.4909615,18.57z/data=!4m6!3m5!1s0x8e30a71c9d0668d9:0xf26d47619bf4a3b7!8m2!3d3.4743543!4d-76.490771!16s%2Fg%2F11rg2qlld1?entry=ttu&g_ep=EgoyMDI2MDQwOC4wIKXMDSoASAFQAw%3D%3D"; // cámbialo por tu ubicación real
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _enviarWhatsApp(String nombre, String acompanante) async {
    if (nombre.isEmpty) {
      return;
    }
    final String mensaje = acompanante.isEmpty
        ? "Hola! Soy $nombre y confirmo mi asistencia para asistir a este evento tan importante el día 17/05/26"
        : "Hola! Soy $nombre y confirmo mi asistencia con mis $acompanante pases para asistir a este evento tan importante el día 17/05/26";

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
        "https://wa.me/573183795157?text=${Uri.encodeComponent(mensaje)}"; // cámbialo por tu número de WhatsApp
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
    _guestConfirmedCountFromRoute = widget.guestConfirmedCount;
    
    // Si hay nombre desde la ruta, establecerlo en el campo
    if (_guestNameFromRoute != null) {
      _nombreCtrl.text = _guestDisplayNameFromRoute ?? _guestNameFromRoute!;
      _selectedNameDisplay = _guestDisplayNameFromRoute ?? _guestNameFromRoute!;
      _passesForTypedName = _guestPassesFromRoute;
    }
    
    if (kIsWeb && !_mapRegistered) {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory('gmap-iframe', (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.openstreetmap.org/export/embed.html?bbox=-76.492%2C3.472%2C-76.489%2C3.476&layer=mapnik&marker=3.4743975%2C-76.4909615'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = '0'
          ..style.borderRadius = '12px'
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
    _acompanante4Ctrl.dispose();
    _acompanante5Ctrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _tryAutoplayWeb() async {
    // Intenta reproducir en silencio y luego hacer fade-in
    try {
      await _player.setVolume(0.0);
      await _player.play(UrlSource('assets/lib/assets/audio/EnMiCorazonEstaras.mp3'));
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
        // Si ya está reproduciendo, no hacer nada
        if (_isPlaying) {
          _firstGestureSub?.cancel();
          _firstGestureSub = null;
          return;
        }
        
        await _player.setVolume(0.0);
        await _player.play(UrlSource('assets/lib/assets/audio/EnMiCorazonEstaras.mp3'));
        await _fadeInVolume(target: 1.0, steps: 10, totalDurationMs: 1000);
        
        debugPrint('Audio iniciado exitosamente después del primer gesto');
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
          await _player.play(UrlSource('assets/lib/assets/audio/EnMiCorazonEstaras.mp3'));
        } else {
          if (_player.source == null) {
            await _player.play(UrlSource('assets/lib/assets/audio/EnMiCorazonEstaras.mp3'));
          } else {
            await _player.resume();
          }
        }
      }
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
      await _player.play(UrlSource('assets/lib/assets/audio/EnMiCorazonEstaras.mp3'));
      _isPlaying = true;
    } catch (e) {
      debugPrint('Start audio error: $e');
    }
  }

  Future<void> _restartMusic() async {
    try {
      // Detener cualquier reproducción anterior
      await _player.stop();
      
      // Reiniciar desde el principio según la plataforma
      if (kIsWeb) {
        await _player.setVolume(0.0);
        await _player.play(UrlSource('assets/lib/assets/audio/EnMiCorazonEstaras.mp3'));
        // Fade-in suave
        await _fadeInVolume(target: 1.0, steps: 10, totalDurationMs: 1200);
      } else {
        await _player.play(UrlSource('assets/lib/assets/audio/EnMiCorazonEstaras.mp3'));
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

  String _humanJoin(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  if (items.length == 2) return '${items[0]} y ${items[1]}';
  final head = items.sublist(0, items.length - 1).join(', ');
  return '$head y ${items.last}';
}

  // Nueva función de confirmación con datos de la ruta
  void _confirmarAsistenciaDesdeRuta() async {
    if (_guestDisplayNameFromRoute == null) return;

    bool _loading = false;
    
    // Verificar si está dentro del plazo de x días
    final now = DateTime.now();
    final deadline = DateTime(2026, 4, 26); // x días antes del evento (17 de mayo)
    final daysRemaining = deadline.difference(now).inDays;
    
    // Mostrar diálogo de confirmación con mensaje de 3 días
    await showDialog<bool>(
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
                if (_loading) ...[
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
                onPressed: _loading ? null : () => Navigator.of(ctx).pop(false),
                child: const Text('Cerrar'),
              ),
              (daysRemaining >= 0 && !_alreadyConfirmed) ?
                ElevatedButton(
                  onPressed: _loading ? null : () async {
                    setDialogState(() => _loading = true);
                    // Descontar pases automáticamente
                    try {
                      final respuesta = await SheetsService.confirm(_guestNameFromRoute!, consume: int.parse(_guestPassesFromRoute.toString()));
                      Navigator.of(ctx).pop(true);
                      await ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('¡Asistencia confirmada! $_guestPassesFromRoute pases descontados'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      setState(() {
                        _alreadyConfirmed = true;
                        _guestConfirmedCountFromRoute = respuesta!['confirmedCount'];
                        // Refrescar estado de soldOut para actualizar UI
                        _refreshSoldOutFromSheets();
                      });
                      // Enviar WhatsApp después de confirmar
                      _enviarWhatsApp(_guestDisplayNameFromRoute!, _guestConfirmedCountFromRoute.toString());
                    } catch (e) {
                      setDialogState(() => _loading = false);
                      Navigator.of(ctx).pop(false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al confirmar: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: _loading 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Confirmar'),
                ) : Text(
                  "Muchas gracias por confirmar.\nNos vemos pronto",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          );
        }
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

  // 🔹 Dentro del build (ajustado)
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double fontSizeTitle = size.width * 0.07; // título grande
    final double fontSizeBody = size.width * 0.045; // texto secundario

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _togglePlayPause,
        backgroundColor: Color(0xFF001F54), // Azul navy
        elevation: 5,
        hoverElevation: 10,
        focusElevation: 10,
        highlightElevation: 10,
        hoverColor: Colors.white,
        tooltip: "En Mi Corazón Estarás",
        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("lib/assets/fondo.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ), // filtro oscuro
          // _buildSideBars(size),
          // 🔹 Contenido desplazable encima
          SingleChildScrollView(
            child: Column(
              children: [
                // 🔹 Sección 1
                Container(
                  height:  size.width > 600 ? size.height * 2.1 : size.height * 1.0,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Contenido
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20), 
                          FittedBox(
                            child: Text(
                              "El amor se multiplica\ny en la famililia habrá\nuna tierna sonrisa\niluminando\nnuestras vidas...",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.parisienne(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSizeTitle + 18,
                                color: Colors.brown[700],
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      blurRadius: 1,
                                      offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ),
                          FittedBox(
                            child: Text(
                              "Con amor e ilusión\nesperamos su llegada",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.baloo2(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSizeTitle + 20,
                                color: Colors.green[900],
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      blurRadius: 1,
                                      offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 🔹 Sección 2 
                // 🔔 Cuenta regresiva (reloj HH:MM:SS)
                // 📅 Calendario
                Container(
                  height:  size.width > 600 ? size.height * 4.2 : size.height * 0.8,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FittedBox(
                            child: Text(
                              "Acompañanos a mi",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.parisienne(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSizeTitle + 20,
                                color: Colors.brown[900],
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      blurRadius: 1,
                                      offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ),
                          TitleAnimated(),
                          FittedBox(
                            child: Text(
                              "Shower",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.parisienne(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSizeTitle + 40,
                                color: Colors.brown[900],
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      blurRadius: 1,
                                      offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ),
                          FittedBox(
                            child: Text(
                              "La dulce espera está\npor terminar",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSizeTitle,
                                color: Colors.green[900],
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      blurRadius: 1,
                                      offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ),
                          FittedBox(
                            child: Text(
                              "GAEL",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSizeTitle + 40,
                                color: Colors.brown[900],
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      blurRadius: 1,
                                      offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 🔹 Sección 3
                Container(
                  // height:  size.width > 600 ? size.height * 4.2 : size.height * 2.2,
                  width: double.infinity,
                  child: Column(
                    children: [
                      // Reloj en bloques: Días | Horas | Minutos | Segundos
                      CountdownWidget(d: _d, h: _h, m: _m, s: _s, size: size),
                      // Calendario Mayo 2026 con corazón en el 17
                      _buildCalendar(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_pin,
                            color: Colors.green[900],
                            size: fontSizeTitle + 20
                          ),
                          Flexible(
                            child: Text(
                              "SEDE COMUNAL LOS GUAYACANES",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                color: Colors.brown[900],
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              "CALLE 64 A #1E-15",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                color: Colors.brown[900],
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
                          backgroundColor: Colors.brown[900],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text("Ver en Google Maps", style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            child: Text(
                              "REGALO:",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontWeight: FontWeight.bold,
                                fontSize: fontSizeTitle,
                                color: Colors.green[900],
                                shadows: const [
                                  Shadow(
                                      color: Colors.black,
                                      blurRadius: 3,
                                      offset: Offset(2, 2)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            children: [
                              Icon(
                                Icons.card_giftcard_rounded,
                                color: Colors.brown[900],
                                size: fontSizeTitle + 20
                              ),
                              Icon(
                                Icons.mail,
                                color: Colors.brown[900],
                                size: fontSizeTitle + 20
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: size.width * 0.12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 20),
                              // Mostrar "cupos a tope" solo si no hay cupos globales Y no es invitado desde la ruta
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
                                  '¡Los cupos están a tope! 💥🎉\n\nYa casi comienza la celebración... ¡nos vemos pronto! 🥳',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.roboto(
                                    color: Colors.brown[900],
                                    fontSize: fontSizeBody,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                              else
                              // 🔹 Widget nuevo
                              InvitadosForm(
                                size: size,
                                fontSizeBody: fontSizeBody,
                                nombreCtrl: _nombreCtrl,
                                acomp1Ctrl: _acompananteCtrl,
                                acomp2Ctrl: _acompanante2Ctrl,
                                acomp3Ctrl: _acompanante3Ctrl,
                                acomp4Ctrl: _acompanante4Ctrl,
                                acomp5Ctrl: _acompanante5Ctrl,
                                passes: _passesForTypedName,
                                soldOut: _soldOut,
                                alreadyConfirmed: _alreadyConfirmed,
                                onNameChanged: (_) => _onNameChanged(),
                                onAskToAttend: () async => _askToAttendDialog(),
                                onConfirm: () async {
                                  // Si viene desde EnvelopePage, usar la función especial
                                  if (_guestNameFromRoute != null) {
                                    _confirmarAsistenciaDesdeRuta();
                                    return;
                                  }
                                  
                                  // Lógica normal para usuarios generales
                                  final nombre = _nombreCtrl.text.trim();
                                  final acomp1 = _acompananteCtrl.text.trim();
                                  final acomp2 = _acompanante2Ctrl.text.trim();
                                  final acomp3 = _acompanante3Ctrl.text.trim();
                                  final acomp4 = _acompanante4Ctrl.text.trim();
                                  final acomp5 = _acompanante5Ctrl.text.trim();
                                  
                                  if (nombre.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Ingresa tu nombre para confirmar.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() => _isConfirming = true);
                                  try {
                                    final guest = await SheetsService.getGuest(nombre);
                                    if (guest == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No encontramos tu nombre.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    final passes = int.tryParse(guest['passesRemaining']?.toString() ?? '0') ?? 0;
                                    if (passes <= 0) {
                                      await _refreshSoldOutFromSheets();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Ya no quedan pases disponibles.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    final companions = [acomp1, acomp2, acomp3, acomp4, acomp5]
                                        .where((e) => e.isNotEmpty)
                                        .toList();
                                    int desired = 1 + companions.length;
                                    if (desired > passes) {
                                      companions.removeRange((passes - 1).clamp(0, 3), companions.length);
                                      desired = 1 + companions.length;
                                    }
                                    final updated = await SheetsService.confirm(nombre, consume: desired);
                                    if (updated == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No se pudo confirmar.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    final acompFinal =
                                        companions.isNotEmpty ? _humanJoin(companions) : '';
                                    _enviarWhatsApp(nombre, acompFinal);
                                    if (mounted) setState(() => _soldOut = false);
                                    await _refreshSoldOutFromSheets();
                                  } finally {
                                    if (mounted) setState(() => _isConfirming = false);
                                  }
                                },
                              ),
                              // 🔹 Sugerencias (SE QUEDAN)
                              if (_nameSuggestions.isNotEmpty)
                                Container(
                                  width: size.width > 600 ? 400 : size.width * 0.75,
                                  constraints: const BoxConstraints(maxHeight: 180),
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.brown[900],
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
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
                                            _ignoreNextNameChange = true;
                                            _selectedNameDisplay = display;
                                            _nombreCtrl.text = display;
                                            _nombreCtrl.selection = TextSelection.collapsed(offset: display.length);
                                            _passesForTypedName = passesRem;
                                            _nameSuggestions = [];
                                          });
                                        },
                                      );
                                    },
                                  ),
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
  // 🔹 Calendario simple: Mayo 2026 con corazón en el día 17
  Widget _buildCalendar() {
    final size = MediaQuery.of(context).size;
    final monthStart = DateTime(2026, 5, 1);
    final daysInMonth = DateTime(2026, 6, 0).day; // 31
    final startWeekday = monthStart.weekday; // 1=Lun ... 7=Dom

    final leadingEmpty = startWeekday - 1; // celdas vacías antes del 1
    final cells = leadingEmpty + daysInMonth;
    final totalCells = ((cells + 6) ~/ 7) * 7; // múltiplo de 7

    TextStyle headerStyle = GoogleFonts.roboto(
      color: Colors.brown[700],
      fontWeight: FontWeight.w600,
      fontSize: size.width > 600 ? 14 : 10,
      shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))],
    );

    TextStyle dayStyle = GoogleFonts.roboto(
      color: Colors.brown[700],
      fontWeight: FontWeight.w500,
      fontSize: size.width > 600 ? 16 : 12,
      shadows: const [Shadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))],
    );

    Widget dayCell(int? day) {
      final isMarked = day == 17;
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isMarked ? Colors.amber.withOpacity(0.2) : Colors.green.withOpacity(0.5),
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
                    child: Icon(
                      Icons.favorite_border,
                      color: Colors.green[900],
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
            'Mayo 2026 - 3:00 PM',
            style: GoogleFonts.playfairDisplay(
              color: Colors.brown[700],
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
}
