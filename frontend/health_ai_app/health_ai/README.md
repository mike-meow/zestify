# Health AI Coach App

A Flutter application for the Health AI Wellness Coach platform, designed with a Robinhood/Apple-inspired UI.

## Features

- Health score visualization with animated orb
- Workout history and statistics
- Dietary tracking and insights
- Motivational content and goal setting
- Chat interface with voice input capability

## Getting Started

### Prerequisites

- Flutter SDK (3.19.x or later)
- Dart SDK (3.7.x or later)
- Xcode for iOS/macOS development
- Android Studio for Android development

### Installation

1. Clone the repository
2. Navigate to the project directory:
   ```
   cd frontend/health_ai_app/health_ai
   ```
3. Install dependencies:
   ```
   flutter pub get
   ```

## Development

### Running the App

You can run the app using VS Code's F5 key or with the following command:

```bash
flutter run
```

For a specific platform:

```bash
flutter run -d macos  # For macOS
flutter run -d ios    # For iOS Simulator
flutter run -d web    # For web
```

### Build and Test

To verify the build and run tests, use the provided script:

```bash
./build_test.sh
```

This script will:

1. Clean the project
2. Get dependencies
3. Analyze the code
4. Run tests
5. Build for iOS, macOS, and web platforms

### Manual Testing

Run tests manually with:

```bash
flutter test
```

### Code Analysis

Check for code issues with:

```bash
flutter analyze
```

## Project Structure

- `lib/main.dart` - Application entry point
- `lib/screens/` - App screens
- `lib/widgets/` - Reusable UI components
- `lib/theme/` - App theme and styling
- `test/` - Unit and widget tests

## Design

The app follows a Robinhood/Apple-inspired design language with:

- Clean, minimalist UI
- Smooth animations
- Bubbly card components
- Gradient colors
- Emphasis on typography and whitespace

## Flutter Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
