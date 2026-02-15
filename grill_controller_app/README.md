# Grill Controller App

A cross-platform Flutter application for monitoring and controlling wifi-connected charcoal grill fan systems.

## Platforms Supported

- Android 8.0 (API 26) and higher
- iOS 12.0 and higher
- Windows 10 (build 17763) and higher

## Architecture

This project follows Clean Architecture principles with clear separation of concerns:

```
lib/
├── core/                 # Core utilities and error handling
│   ├── error/           # Error types and handlers
│   └── utils/           # Utility functions
├── data/                # Data layer
│   ├── datasources/     # Remote and local data sources
│   ├── models/          # Data models
│   └── repositories/    # Repository implementations
├── domain/              # Domain layer (business logic)
│   ├── entities/        # Business entities
│   ├── repositories/    # Repository interfaces
│   └── usecases/        # Business use cases
└── presentation/        # Presentation layer
    ├── bloc/            # BLoC state management
    ├── screens/         # UI screens
    └── widgets/         # Reusable widgets
```

## Key Dependencies

### State Management
- `flutter_bloc` - BLoC pattern for state management
- `equatable` - Value equality for entities

### Local Storage
- `hive` - Lightweight key-value storage
- `sqflite` - SQLite for time-series temperature data
- `path_provider` - Platform-specific paths

### Device Communication
- `flutter_blue_plus` - Bluetooth Low Energy
- `http` - HTTP client for wifi communication
- `wifi_iot` - Wifi configuration

### UI Components
- `fl_chart` - Temperature graphs
- `responsive_framework` - Responsive layouts

### Utilities
- `share_plus` - Native sharing
- `intl` - Internationalization
- `uuid` - UUID generation

### Testing
- `bloc_test` - BLoC testing utilities
- `faker` - Test data generation

## Getting Started

### Prerequisites

- Flutter SDK 3.11.0 or higher
- Dart 3.11.0 or higher

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

```bash
# Run on connected device
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
flutter run -d windows
```

### Building

```bash
# Android
flutter build apk
flutter build appbundle

# iOS
flutter build ios

# Windows
flutter build windows
```

## Platform-Specific Configuration

### Android

Minimum SDK: 26 (Android 8.0)

Required permissions (already configured in AndroidManifest.xml):
- Bluetooth (BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
- Location (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION) - required for Bluetooth scanning
- Wifi (ACCESS_WIFI_STATE, CHANGE_WIFI_STATE, CHANGE_NETWORK_STATE, ACCESS_NETWORK_STATE)
- Internet (INTERNET)

### iOS

Minimum version: iOS 12.0

Required usage descriptions (already configured in Info.plist):
- NSBluetoothAlwaysUsageDescription
- NSBluetoothPeripheralUsageDescription
- NSLocalNetworkUsageDescription
- NSBonjourServices

### Windows

Minimum version: Windows 10 build 17763

Network permissions are configured in the app manifest.

## Features

- Device pairing via Bluetooth
- Real-time temperature monitoring (1 grill probe + up to 3 food probes)
- Automatic fan control with customizable speed curves
- Grill-open detection and automatic fan pause/resume
- Multi-stage cook programs
- Cook history and notes
- Social sharing with temperature graphs
- Responsive design for phone, tablet, and desktop

## Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## Development Notes

- The project uses BLoC pattern for state management
- All business logic is in the domain layer
- Repository pattern abstracts data sources
- Property-based testing is used for correctness validation
- Hive is used for lightweight data, SQLite for time-series data

## License

[Add your license here]
