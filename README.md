# ZZU PreOmar — Campus Pre‑owned Market (Flutter)

Front-end for Zhengzhou University’s campus marketplace. Students list, browse, and trade pre‑owned items with authentication, messaging, wishlist, and profile stats.

## What it does

This app lets students authenticate with their university email, browse categories of items, search for specific products, list their own items for sale, and message other users. I've included a complete profile system with wishlist, order history, and reviews functionality.

## Getting Started

- **Requirements**: Flutter 3+, Android SDK, VS Code/Android Studio
- **Install**: `flutter pub get`
- **Run (Android)**: `flutter run` or use [run_app.bat](run_app.bat)
- **Run (Web)**: `flutter run -d chrome` or use [run_web.bat](run_web.bat)
- **Tests**: `flutter test` or [run_tests.bat](run_tests.bat)

## Build & APK
- **Release APK**: `flutter build apk --release`
- **APK Path**: `build/app/outputs/flutter-apk/app-release.apk`
- **App Bundle**: `flutter build appbundle --release`
- **Web**: `flutter build web --release`

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # All screen widgets
│   ├── auth/                # Authentication screens
│   │   ├── login_screen.dart
│   │   ├── admin_login_screen.dart
│   │   └── forgot_password_screen.dart
│   ├── home/                # Home screen
│   │   └── home_screen.dart
│   ├── product/             # Product-related screens
│   │   ├── product_detail_screen.dart
│   │   ├── search_screen.dart
│   │   └── sell_screen.dart
│   ├── messages/            # Messaging screens
│   │   ├── messages_screen.dart
│   │   └── notifications_screen.dart
│   ├── profile/             # Profile screens
│   │   ├── profile_screen.dart
│   │   ├── my_listings_screen.dart
│   │   ├── wishlist_screen.dart
│   │   ├── order_history_screen.dart
│   │   └── reviews_screen.dart
│   └── splash_screen.dart   # Splash screen
├── widgets/                 # Reusable widgets
│   ├── bottom_nav.dart      # Bottom navigation
│   ├── logo_widget.dart     # App logo
│   └── product_card.dart    # Product display card
└── utils/                   # Utilities and constants
    ├── app_colors.dart      # Color scheme
    ├── models.dart          # Data models
    └── validators.dart      # Form validators
```

## Features
- **Auth**: Register, email verification (6‑digit), login, logout, session restore
- **Password Reset**: Request code and reset password
- **Profile**: Name, email, student ID, verified badge, dynamic stats
- **Stats**: Items sold and total items via `/my-products/stats`
- **Products**: List, details, mark sold, delete
- **Wishlist**: Add/remove, check state
- **Messages**: Conversation list, product buy requests, send messages
- **Icons**: Custom app icon via `flutter_launcher_icons`

## Configuration
- **Backend Base**: `https://backend-for-app-main-hsw776.laravel.cloud/api`
- **Headers**: `Accept: application/json`, `Authorization: Bearer <token>`
- **Token Storage**: SharedPreferences via `AuthState`
- **Student ID Masking**: Registration input is obscured (`2023800.....`) in [lib/screens/auth/login_screen.dart](lib/screens/auth/login_screen.dart)

## Authentication Flows
- **Register**: name, email, phone, password, confirm, student_id
- **Verify Email**: POST `/auth/verify-email` → `email`, `verification_code`
- **Login**: POST `/auth/login` → nested `data.user` + `data.token`
- **Session**: GET `/auth/me` → `data.user`
- **Forgot Password**: POST `/auth/forgot-password` → `email_sent`
- **Reset Password**: POST `/auth/reset-password` → `reset_code`, new password
- **Logout**: POST `/auth/logout`

## Messaging & Wishlist
- **Conversations**: Grouped by counterpart with last message preview
- **Send**: Posts messages; buy requests render readable previews
- **Wishlist**: Check/add/remove via `/wishlist` endpoints

## Products
- **Card layout**: Consistent crop via `AspectRatio(1.2)` + `BoxFit.cover` in [lib/widgets/product_card.dart](lib/widgets/product_card.dart)
- **Mark sold**: POST `/sells` with `product_id` (+ optional `buyer_user_id`)
- **Delete**: DELETE `/products/{id}/delete`

## App Icons
- Config in [pubspec.yaml](pubspec.yaml) using `flutter_launcher_icons`
- Foreground: `assets/icon/app_icon_foreground.png` (tight crop)
- Background: `#FFF8F0`
- Generate: `flutter pub run flutter_launcher_icons`

## Assumptions I made

I validated university emails for the @zzu.edu.cn domain specifically. Pricing uses Chinese Yuan since it's for a Chinese university. The interface is in English but designed for the Chinese university context. I assumed users will have internet connectivity for loading images.

## Troubleshooting
- **Nested data**: Parse `data.data.user` and `data.data.token` for login
- **Expired token**: Redirects to login and shows SnackBar
- **Messages jump**: Auto‑scroll disabled on load; scrolls after sending
- **Image fit**: AspectRatio keeps cards aligned across lists
- **APK size**: Unused assets removed; images cached

## Roadmap
- Push notifications, real‑time chat, advanced filters, multi‑language, offline caching, admin tools

## Credits
- Internal project for ZZU campus community. Assets and icons provided by the project owner.