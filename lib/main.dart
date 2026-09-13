import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/reader_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniversalReaderApp());
}

class UniversalReaderApp extends StatefulWidget {
  const UniversalReaderApp({super.key});

  @override
  State<UniversalReaderApp> createState() => _UniversalReaderAppState();
}

class _UniversalReaderAppState extends State<UniversalReaderApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Universal Reader',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorSchemeSeed: const Color(0xFF2563EB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorSchemeSeed: const Color(0xFF2563EB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      themeMode: _themeMode,
      home: AppRootPage(
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

class AppRootPage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;

  const AppRootPage({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<AppRootPage> createState() => _AppRootPageState();
}

class _AppRootPageState extends State<AppRootPage> {
  static const platform = MethodChannel('app.channel.shared.data');
  String? _activeFilePath;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _checkInitialSharedFile();
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onFileOpened') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _openFile(path);
        }
      }
    });
  }

  Future<void> _checkInitialSharedFile() async {
    try {
      final String? path = await platform.invokeMethod('getSharedFilePath');
      if (path != null && path.isNotEmpty) {
        _openFile(path);
      }
    } on PlatformException catch (_) {}
  }

  void _openFile(String path) {
    setState(() {
      _activeFilePath = path;
    });
  }

  void _closeFile() {
    setState(() {
      _activeFilePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _activeFilePath == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _activeFilePath != null) {
          _closeFile();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _activeFilePath != null
            ? ReaderScreen(
          key: ValueKey(_activeFilePath),
          filePath: _activeFilePath!,
          onThemeChanged: widget.onThemeChanged,
          onClose: _closeFile,
        )
            : HomeScreen(
          key: const ValueKey('home_screen'),
          onFileSelected: _openFile,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );
  }
}