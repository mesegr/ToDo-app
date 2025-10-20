import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/task.dart';
import '../models/repetition_type.dart';

class AlarmScreen extends StatefulWidget {
  final Task task;
  final Function(String taskId)? onDismiss;

  const AlarmScreen({super.key, required this.task, this.onDismiss});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Ocultar barras de sistema para pantalla completa inmersiva
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Iniciar vibración continua
    _startContinuousVibration();

    // Animación de pulso para el ícono
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de sacudida para el botón
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _shakeAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startContinuousVibration() async {
    bool? hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator == true) {
      // Vibración MUY intensa y continua
      // Patrón: vibra 800ms, pausa 200ms, repite indefinidamente
      await Vibration.vibrate(
        pattern: [0, 800, 200],
        intensities: [0, 255, 0], // Intensidad máxima
        repeat: 0, // Repetir desde el índice 0 indefinidamente
      );
    }
  }

  @override
  void dispose() {
    // Restaurar barras de sistema al salir
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    _pulseController.dispose();
    _shakeController.dispose();
    Vibration.cancel();
    super.dispose();
  }

  void _dismissAlarm() async {
    // Detener vibración
    await Vibration.cancel();

    // Si la tarea no es repetitiva, llamar al callback para eliminarla
    if (widget.onDismiss != null) {
      widget.onDismiss!(widget.task.id);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener dimensiones completas de la pantalla
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1F1A2E),
      body: Container(
        width: size.width,
        height: size.height,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              // Ícono de alarma animado
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.alarm, size: 64, color: Colors.white),
                ),
              ),

              const SizedBox(height: 48),

              // Título
              const Text(
                '⏰ ALARMA',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 24),

              // Nombre de la tarea
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF352D47),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.task.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Información de repetición
              Text(
                widget.task.getRepetitionDescription(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Botón para descartar con animación de sacudida
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton(
                    onPressed: _dismissAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF8B5CF6).withOpacity(0.5),
                    ),
                    child: const Text(
                      'DETENER ALARMA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Mensaje adicional para tareas no repetitivas
              if (widget.task.repetitionType == RepetitionType.none)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange[300],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Esta tarea se eliminará al detener la alarma',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[300],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
