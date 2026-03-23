import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Importações do projeto
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart'; // <--- ADICIONADO

void main() async {
  // 1. Garante a inicialização dos bindings do Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa o Firebase
  await Firebase.initializeApp();

  // 3. Inicializa o Serviço de Notificações (Local e Push)
  // Isso permite que o app agende lembretes e receba mensagens do Firebase
  await NotificationService().inicializar(); // <--- ADICIONADO

  // 4. Inicializa a localização para datas em Português
  await initializeDateFormatting('pt_BR', null);

  // 5. Roda o App com o ProviderScope (necessário para o Riverpod)
  runApp(const ProviderScope(child: GeoPontoApp()));
}

class GeoPontoApp extends StatelessWidget {
  const GeoPontoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoPonto Pro',
      debugShowCheckedModeBanner: false,
      
      // Configuração de Idioma e Região
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Tema Visual do Aplicativo
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
          brightness: Brightness.light,
        ),
        primaryColor: const Color(0xFF15803D),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF15803D),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF15803D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// O AuthWrapper gerencia o estado da sessão.
/// Ele decide se mostra o Login, o Dashboard do Admin ou a Home do Colaborador.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa o estado da autenticação do Firebase
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        // Se não houver usuário logado, vai para Login
        if (user == null) return const LoginPage();

        // Se houver usuário, observa o perfil detalhado no Firestore
        final profile = ref.watch(userProfileProvider);
        
        return profile.when(
          data: (u) {
            if (u == null) return const LoginPage();
            
            // Verifica o nível de acesso (Admin ou Colaborador)
            if (u.isAdmin) return const AdminDashboardPage();
            return const HomePage();
          },
          loading: () => const _SplashScreen(),
          error: (_, __) => const LoginPage(),
        );
      },
      loading: () => const _SplashScreen(),
      error: (_, __) => const LoginPage(),
    );
  }
}

/// Tela de carregamento exibida durante a verificação de sessão
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF15803D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text('GeoPonto Pro',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white70),
          ],
        ),
      ),
    );
  }
}