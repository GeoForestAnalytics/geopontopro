# GeoPonto Pro — Flutter App

App de registro de ponto com geolocalização, histórico mensal e assinatura digital.

---

## Estrutura de arquivos

```
lib/
├── main.dart                          ← Entrada do app
├── models/
│   ├── user_model.dart                ← Model do usuário
│   └── ponto_model.dart               ← Model de ponto e fechamento
├── providers/
│   └── auth_provider.dart             ← Providers Riverpod + AuthService
├── services/
│   └── ponto_service.dart             ← Lógica de GPS, Firestore, assinatura
└── pages/
    ├── login_page.dart                ← Tela de login
    ├── home_page.dart                 ← Tela principal (funcionário)
    ├── historico_page.dart            ← Histórico mensal por dia
    ├── assinatura_page.dart           ← Assinatura digital do mês
    ├── admin_dashboard_page.dart      ← Dashboard admin (pontos do dia)
    ├── admin_funcionarios_page.dart   ← Gerenciar funcionários
    └── admin_relatorio_page.dart      ← Relatório mensal por funcionário
```

---

## Setup

### 1. Firebase

1. Crie um projeto no [Firebase Console](https://console.firebase.google.com)
2. Ative **Authentication** (Email/Senha)
3. Ative **Cloud Firestore**
4. Adicione app Android e/ou iOS
5. Baixe `google-services.json` (Android) ou `GoogleService-Info.plist` (iOS)
6. Execute: `flutterfire configure` para gerar `firebase_options.dart`

### 2. Dependências

```bash
flutter pub get
```

### 3. Permissões Android

Em `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 4. Permissões iOS

Em `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para registrar o ponto.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Precisamos da sua localização para registrar o ponto.</string>
```

### 5. Criar primeiro admin manualmente

No Firestore, crie o documento em `usuarios/{uid}`:
```json
{
  "nome": "Seu Nome",
  "email": "admin@empresa.com",
  "cargo": "Administrador",
  "empresa": "Nome da Empresa",
  "isAdmin": true,
  "criadoEm": "2024-01-01T00:00:00Z"
}
```
O uid deve ser o mesmo gerado pelo Firebase Authentication.

---

## Estrutura do Firestore

```
/usuarios/{uid}
  nome, email, cargo, empresa, isAdmin, criadoEm

/pontos/{id}
  usuarioId, usuarioNome, tipo, timestamp,
  latitude, longitude, endereco, offline

/fechamentos/{usuarioId}_{ano}_{mes}
  usuarioId, usuarioNome, mes, ano,
  assinaturaBase64, assinadoEm, fechado
```

## Índices Firestore necessários

Crie os índices compostos:
- `pontos`: `usuarioId ASC` + `timestamp ASC`
- `pontos`: `timestamp ASC` (para admin)

---

## Funcionalidades

- ✅ Login com Firebase Auth
- ✅ Bater ponto com GPS (entrada, saída almoço, retorno almoço, saída)
- ✅ Endereço reverso automático (geocoding)
- ✅ Modo offline (registra sem GPS se necessário)
- ✅ Histórico mensal agrupado por dia com horas trabalhadas
- ✅ Assinatura digital ao fechar o mês
- ✅ Dashboard admin com presença em tempo real
- ✅ Gerenciamento de funcionários pelo admin
- ✅ Relatório mensal com horas totais por funcionário
