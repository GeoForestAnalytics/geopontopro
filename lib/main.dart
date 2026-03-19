import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'pages/login_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/home_page.dart';

// Importações para as datas funcionarem em Português
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  // 1. Garante a inicialização dos plugins
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa o Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. O PULO DO GATO: Inicializa a formatação de datas em PT-BR
  // Sem essa linha, o App dá erro de tela vermelha na HomePage
  await initializeDateFormatting('pt_BR', null);

  runApp(const GeoPontoApp());
}

class GeoPontoApp extends StatelessWidget {
  const GeoPontoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Ponto Pro',
      debugShowCheckedModeBanner: false,
      
      // 4. Define o idioma padrão do App para Português
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        primaryColor: Colors.green[800],
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('usuarios')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userDoc) {
              if (userDoc.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (userDoc.hasError || !userDoc.hasData || !userDoc.data!.exists) {
                return const LoginPage();
              }

              final dados = userDoc.data!.data() as Map<String, dynamic>?;
              final String cargo = dados?['cargo'] ?? 'colaborador';

              if (cargo == 'gerente') {
                return const AdminDashboard();
              } else {
                return const HomePage();
              }
            },
          );
        }

        return const LoginPage();
      },
    );
  }
}