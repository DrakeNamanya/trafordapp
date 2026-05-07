# Traford Farm Fresh — Mobile App

Flutter mobile app for **Traford Farm Fresh**, an e-commerce platform that connects Ugandan smallholder farmers directly to consumers.

This app is part of a 3-project ecosystem that all share **one Supabase backend**:

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Flutter App        │     │   Public Website     │     │   Admin Portal       │
│   (this repo)        │     │   trafordfresh-web   │     │   trafordfresh       │
└──────────┬───────────┘     └──────────┬───────────┘     └──────────┬───────────┘
           │                            │                            │
           └────────────────┬───────────┴────────────────────────────┘
                            │
                  ┌─────────▼──────────┐
                  │     Supabase        │
                  │  (shared database)  │
                  └────────────────────┘
```

## ✨ Features

- 🏠 **Home dashboard** — hero carousel, category tiles, featured products, promo banners
- 🛍️ **Shop** — browse, search, filter by category, sort
- 🛒 **Cart & Wishlist** — synced to Supabase per user
- 📦 **Orders** — full order history and tracking
- 👤 **Profile** — account management
- 🔔 **Notifications** — order updates and promotions
- 💳 **Checkout** — multi-step checkout flow
- 🔐 **Auth** — Supabase email/password authentication

## 🛠️ Tech Stack

- **Framework:** Flutter 3.35.4 / Dart 3.9.2
- **State Management:** Provider
- **Backend:** Supabase (PostgreSQL + Auth + Realtime)
- **Local Storage:** shared_preferences, Hive
- **HTTP:** http package
- **Carousel:** carousel_slider
- **Fonts/Icons:** google_fonts, font_awesome_flutter

## 📁 Project Structure

```
lib/
├── main.dart
├── models/
│   └── product.dart           # Product, Category, CartItem, Order, AppUser, Review
├── screens/
│   ├── home_screen.dart        # Home dashboard
│   ├── shop_screen.dart        # Browse & search
│   ├── product_detail_screen.dart
│   ├── cart_screen.dart
│   ├── checkout_screen.dart
│   ├── orders_screen.dart
│   ├── profile_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   └── notifications_screen.dart
├── services/
│   ├── supabase_config.dart    # Supabase initialization
│   ├── product_service.dart    # Products & categories
│   ├── cart_service.dart       # Cart & wishlist
│   └── auth_service.dart       # Authentication
├── theme/
│   └── app_theme.dart          # Brand colors & ThemeData
└── widgets/
    ├── product_card.dart
    ├── hero_carousel.dart
    └── horizontal_product_list.dart
```

## 🎨 Brand Colors

- **Traford Orange** `#F15A24` — primary actions
- **Growth Green** `#22B14C` — success / nature
- **Soft Leaf** `#8CC63F` — accent

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.35.4
- Dart 3.9.2
- Android Studio / VS Code
- A Supabase project (URL + anon key)

### Setup

```bash
# Clone the repo
git clone https://github.com/DrakeNamanya/trafordapp.git
cd trafordapp

# Install dependencies
flutter pub get

# Run on a device or emulator
flutter run
```

### Supabase Configuration

The app reads its Supabase credentials from `lib/services/supabase_config.dart`:

```dart
static const String url = 'https://YOUR-PROJECT.supabase.co';
static const String anonKey = 'YOUR-ANON-KEY';
```

> The **anon key** is safe to ship in client apps because access is enforced
> by Row Level Security (RLS) policies on the database.

### Building a Release APK

```bash
flutter build apk --release
```

The release build is signed using the keystore configured in
`android/key.properties` (not committed to the repo — see Security below).

## 🔐 Security Notes

These files are **gitignored** and should never be committed:

- `android/key.properties` — keystore passwords
- `android/release-key.jks` (or any `*.jks` / `*.keystore`)
- `firebase-admin-sdk*.json` — server-side admin credentials

For CI/CD, store these as encrypted secrets (e.g. GitHub Actions Secrets)
and inject them at build time.

## 🌍 Shared Backend Architecture

This Flutter app, the public marketplace website, and the admin portal all
read and write to the **same Supabase database**. This means:

- A user who signs up on the website can log in to the mobile app with the
  same credentials and see their order history
- When a director updates a product's image in the admin portal, the change
  appears immediately in both the app and the website (with Supabase
  Realtime, even without a refresh)
- Cart and wishlist state are synced per user across devices

Role-based access is enforced via Supabase RLS policies on the `users.role`
column (`customer`, `admin`, `director`).

## 📦 Related Repositories

- **Admin Portal:** [DrakeNamanya/trafordfresh](https://github.com/DrakeNamanya/trafordfresh)
- **Public Website:** *coming soon* — `trafordfresh-web`

## 📄 License

Proprietary — © 2025 Traford Farm Fresh. All rights reserved.

## 📫 Contact

- Email: sales@trafordfarmfresh.com
- Phone: +256 764 201 606
- Address: Kikaaya, Kyebando, Kawempe, Kampala (U)
