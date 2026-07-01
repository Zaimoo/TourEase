# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

TourEase is a Flutter tourism wayfinding app for Iligan City. Its core feature is a
**multimodal routing engine** that scores and renders trips combining walking, jeepney,
habal-habal (motorcycle taxi), and sikad (pedicab) transport. Backend is Firebase
(Auth + Cloud Firestore); maps and directions use Google Maps.

## Commands

```bash
flutter pub get                      # install dependencies
flutter run                          # run on connected device/emulator
flutter analyze                      # lint (uses analysis_options.yaml / flutter_lints)
flutter test                         # run all tests
flutter test test/widget_test.dart   # run a single test file
flutter build apk                    # release Android build
```

There are currently no real tests beyond the default scaffold; the `test/` directory may
be empty or minimal.

## Architecture

### Startup flow
`main.dart` → `Firebase.initializeApp()` → `SplashScreen`. The splash screen decides the
first route via `SharedPreferences` + auth state:
- no `hasSeenOnboarding` flag → `OnboardingScreen`
- logged in (`UseAuth().user != null`) → `RootPage`
- otherwise → `LoginScreen`

`RootPage` is a manual two-tab shell (Discover, Map) using a `NavigationBar` and an
`int _selectedIndex` switch — there is no named-route table or router package. Navigation
between screens is done with `Navigator.push(MaterialPageRoute(...))`. `RootPage` can be
constructed with `initialTab` / `destinationData` / `initialCameraTarget` so Discover can
hand a selected destination off to the Map tab.

### Data layer
All Firestore access goes through the generic repository in
`lib/services/use_firebase.dart`:

```dart
UseFirebase<T>({ required fromJson, required toJson })
```

Each screen instantiates its own `UseFirebase<Model>` and passes the collection name as a
string to every call (`getAll('destinations')`, `streamAll('transportationMarkers')`,
etc.). Subcollection helpers live in the `UseFirebaseSubcollection` extension. Auth is
wrapped separately in `lib/services/use_auth.dart` (`UseAuth`).

**Firestore collections** (collection names are string literals scattered across screens —
grep before renaming):
- `destinations` — `Destination` (each has `coordinates` GeoPoint, `category`, fare/fee)
  - `destinations/{id}/reviews` subcollection — `Review`
- `users` — `AppUser`, keyed by Firebase Auth UID (`addWithUid`)
  - `users/{uid}/favorites` subcollection
  - `users/{uid}/trips` subcollection — `Trip` (visited history)
- `jeepneyRoutes` — `JeepneyRoute` (ordered `List<GeoPoint>` defining the route line)
- `transportationMarkers` — `TransportationMarkers` (`vehicleType` ∈ jeepney/habal/sikad
  plus a `coordinates` GeoPoint; these are the pickup points the router snaps to)

Models live in `lib/models/`. Each model owns `fromJson(data, id)` / `toJson()` and
exposes a `latLng` getter that converts its Firestore `GeoPoint`.

### Routing engine — `lib/view/map_screen.dart`
This single file is ~5000 lines and is the heart of the app. Treat it as the primary
working surface for any transport/navigation change. Key concepts:

- **Scoring**: `calculateRouteScore(distance, fare, {mode})` normalizes fare and distance
  to 0–10 and combines them **60% fare / 40% distance — lower score is better**. Each mode
  has its own `maxFare` for normalization (jeepney 60, habal 370, sikad 30, walking 1,
  jeepney+jeepney 120, jeepney+habal 450).
- **Jeepney routing**: `_getJeepneyRoutes(user, dest)` snaps both endpoints to the nearest
  point on stored `jeepneyRoutes` and supports single-ride and double-ride (transfer)
  trips via `transferPointA` / `transferPointB`. `_setupJeepneyRouteWithPolylines` is the
  dedicated-button path; the multimodal scoring path mirrors its logic.
- **Other modes**: `_findNearestHabal` / `_findNearestSikad` search
  `transportationMarkers`. Walking/sikad get `_walkingPenaltyMultimodal`; jeepney uses a
  separate walking-penalty rule.
- **Tasks**: a route is decomposed into a `List<Task>`-like step sequence (walk → ride →
  transfer …) advanced by live `geolocator` position updates. `_SavedNavState` is a
  `static` holder so active navigation survives MapScreen rebuilds on tab switches without
  keeping the native Google Map view in memory.
- Directions are fetched from the Google Directions REST API
  (`https://maps.googleapis.com/maps/api/directions/json`) and decoded with
  `flutter_polyline_points`.

`docs/multimodal_implementation_plan.md` and `docs/multimodal_implementation_summary.md`
describe the routing/scoring rules in detail (fare formulas, sikad 2 km cap, penalty
constants) — read these before changing scoring or fares.

### UI
Reusable widgets are in `lib/widgets/` (`destination_card.dart`, `custom_drawer.dart`,
`review_card.dart`, `big_text.dart`, `small_text.dart`, etc.). Screens are in `lib/view/`.
Fonts come from `google_fonts`; map styling from `assets/map_style.json`. Transport marker
icons are PNG assets (`assets/jeepney.png`, `assets/habal.png`, `assets/sikad.png`) — new
assets must be registered under `flutter: assets:` in `pubspec.yaml`.

## Important notes

- **Google Maps Directions API key is hardcoded** in `lib/view/map_screen.dart` and
  `lib/widgets/destination_card.dart` (same literal repeated). The Android Maps key lives
  in the Android manifest, and Firebase keys are in `lib/firebase_options.dart`. There is
  no `.env` / config indirection.
- `firebase_options.dart` exists but `main.dart` calls bare `Firebase.initializeApp()`
  (relying on platform config files like `android/app/google-services.json`), not
  `DefaultFirebaseOptions`.
- Error handling in services is inconsistent (`UseAuth.signIn` swallows errors with
  `print`); follow the surrounding pattern of the file you're editing.
</content>
</invoke>