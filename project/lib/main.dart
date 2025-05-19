import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:project/providers/auth_provider.dart';
import 'package:project/providers/job_provider.dart';
import 'package:project/screens/home_screen.dart';
import 'package:project/screens/welcome_screen.dart';
import 'package:project/services/auth_service.dart';
import 'package:project/services/api_service.dart';
import 'package:project/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:project/screens/login_screen.dart';
import 'package:project/screens/register_screen.dart';
import 'package:project/screens/main_navigator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  // Add error handling for Firebase initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
    // Handle error appropriately (e.g., show error UI)
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            AuthService(),
            StorageService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => JobProvider(
            ApiService(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Enhancer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WelcomeScreen(),  // Start the app with the WelcomeScreen
      routes: {
        '/welcome': (_) => WelcomeScreen(),
        '/home': (_) => HomeScreen(),
        '/register': (_) => RegisterScreen(),
        '/login': (_) => LoginScreen(),
        '/main': (context) {
  return MainNavigator();
},
         '/result': (context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is! String) {
      return const Scaffold(body: Center(child: Text('Invalid job ID')));
    }
    
    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    jobProvider.loadJobs();
    
    return MainNavigator();
  },
      },
    );
  }
}
