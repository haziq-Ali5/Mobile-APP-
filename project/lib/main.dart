
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:project/models/processing_job_hive.dart';
import 'package:project/models/job_status_adapter.dart';
import 'package:project/providers/auth_provider.dart';
import 'package:project/providers/job_provider.dart';
import 'package:project/screens/home_screen.dart';
import 'package:project/screens/welcome_screen.dart';
import 'package:project/services/auth_service.dart';
import 'package:project/services/api_service.dart';
import 'package:project/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:project/screens/login_screen.dart';
import 'package:project/screens/register_screen.dart';
import 'package:project/screens/main_navigator.dart';
import 'package:project/screens/result_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize Hive for Flutter (Web, Mobile, Desktop).
  await Hive.initFlutter();

  // 2) Register the generated adapter for ProcessingJobHive
  Hive.registerAdapter(ProcessingJobHiveAdapter());
  Hive.registerAdapter(JobStatusAdapter());

  // 3) Open a Hive box where we'll store ProcessingJobHive objects
  await Hive.openBox<ProcessingJobHive>('jobs_box');

  // 4) Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
    // You might show an error UI here if desired.
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
        ChangeNotifierProxyProvider<AuthProvider, JobProvider>(
          // Create JobProvider with an ApiService instance
          create: (_) => JobProvider(ApiService()),
          // Whenever AuthProvider changes, update JobProvider’s userId
          update: (_, authProvider, jobProvider) {
  final uid = authProvider.user?.uid;

  // Avoid calling notifyListeners() during build
  Future.microtask(() {
    jobProvider?.setUserId(uid ?? '');
  });

  return jobProvider!;
},
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
      home: const WelcomeScreen(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/home': (_) => const HomeScreen(),
        '/register': (_) => const RegisterScreen(),
        '/login': (_) => const LoginScreen(),
        '/main': (_) {
          return const MainNavigator();
        },
        '/result': (context) {
  final routeArgs = ModalRoute.of(context)?.settings.arguments;
  if (routeArgs is! String) {
    return const Scaffold(
      body: Center(child: Text('Invalid job ID')),
    );
  }

  return ResultScreen(jobId: routeArgs);
        },
      },
    );
  }
}
