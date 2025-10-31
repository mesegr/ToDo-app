import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/add_task_screen.dart';
import 'services/notification_service.dart';
import 'services/alarm_worker.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Workmanager para alarmas en segundo plano
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );

  // Inicializar el servicio de notificaciones
  await NotificationService().initialize();

  // Inicializar el widget
  await WidgetService.initialize();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  static const platform = MethodChannel('com.example.todo_app/intent');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _handleIntent();
  }

  Future<void> _handleIntent() async {
    try {
      final String? action = await platform.invokeMethod('getInitialIntent');
      if (action == 'ADD_TASK') {
        // Esperar a que el widget tree esté construido
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const AddTaskScreen()),
          );
        });
      }
    } catch (e) {
      print('Error al manejar intent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Todo App',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF8B5CF6), // Morado-violeta más vibrante
          secondary: const Color(0xFFA78BFA), // Violeta claro
          surface: const Color(
            0xFF352D47,
          ), // Fondo oscuro con toque violeta más claro
          error: Colors.red[300]!,
        ),
        scaffoldBackgroundColor: const Color(0xFF1F1A2E),
        cardTheme: CardThemeData(
          color: const Color(
            0xFF352D47,
          ), // Card con toque violeta que destaca más
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF544D61)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Color(0xFF7B7B8B)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
