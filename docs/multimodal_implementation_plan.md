# Multimodal Jeepney Scoring Sync + Sikad Algorithm

## Background

There are two separate code paths that handle jeepney routing:

| Path                          | Where                                                   | Status                                                                                                                                                                                                                                             |
| ----------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Dedicated Jeepney button**  | `_setupJeepneyRouteWithPolylines`                       | ✅ Up-to-date — uses `_getJeepneyRoutes`, slices actual route polylines, handles single + double ride correctly with `transferPointA`/`B`                                                                                                          |
| **Multimodal option scoring** | `_setupMediumDistanceRoute` + `_setupLongDistanceRoute` | ❌ Outdated — computes jeepney score using straight-line distance from pickup → dropoff on the **first route only**, ignores double-ride, and calls `_setupJeepneyRouteWithPolylines` for execution (meaning scoring & execution are inconsistent) |

---

## Problems Found

### 1. Outdated jeepney scoring in `_setupMediumDistanceRoute` (lines ~1870–1907)

```dart
// ❌ Only looks at firstRoute, ignores double-ride
final jeepneyPickup = _findNearestPoint(firstRoute.points..., userLocation);
final jeepneyRide = calculateDistance(jeepneyPickup → destination); // straight-line, not on-route
final fare = calculateJeepneyFare(jeepneyRide);  // ignores second leg fare
```

### 2. Outdated jeepney scoring in `_setupLongDistanceRoute` (lines ~1956–1974)

```dart
// ❌ Same issue: only firstRoute, jeepneyDropoff is nearest to destination on firstRoute
jeepneyPickup = _findNearestPoint(firstRoute.points..., userLocation);
jeepneyDropoff = _findNearestPoint(firstRoute.points..., destination); // wrong for double ride
// Then fare computed as single leg: calculateJeepneyFare(pickup→dropoff straight-line)
```

**For double rides this is especially wrong**: the fare is calculated as one single leg across both routes instead of as two separate fares, and `jeepneyDropoff` would be on Route A — not Route B — so the score is meaningless.

### 3. Sikad algorithm missing entirely

`calculateSikadFare` is a placeholder (`return 15.0`). Sikad is in the transport preferences toggle but is never scored or routed in `_setupMediumDistanceRoute` or `_setupLongDistanceRoute`.

### 4. No walking penalty for Walking and Sikad in multimodal

Walking and Sikad are not penalized for long walking segments in multimodal scoring. Add a separate penalty slope for these options (1.5).

---

## Proposed Changes

### [MODIFY] [map_screen.dart](file:///c:/Users/reyce/StudioProjects/TourEase/lib/view/map_screen.dart)

---

#### Fix 1 — `calculateSikadFare` (line ~1224)

Replace the placeholder with the real fare formula:

- **< 1 km** → ₱10 flat
- **Each additional 500 m** → +₱10
- **Max distance: 2 km** (enforced at call sites, not in the formula)

```dart
double calculateSikadFare(double distanceKm) {
  if (distanceKm <= 1.0) return 10.0;
  // Every 500m above the first km adds ₱10
  final extra500mBlocks = ((distanceKm - 1.0) / 0.5).ceil();
  return 10.0 + (extra500mBlocks * 10.0);
  // Result at max (2km): ₱10 + 2×₱10 = ₱30
}
```

Also update `calculateRouteScore`'s `maxFare` for `"sikad"`:

```dart
case "sikad":
  maxFare = 30.0;  // max at 2km
  break;
```

---

#### Fix 2 — Add `_findNearestSikad` helper (near `_findNearestHabal`)

Sikad markers already exist in Firestore (vehicle type `"sikad"`). Add a parallel helper:

```dart
Future<TransportationMarkers?> _findNearestSikad(LatLng userLocation) async {
  final markers = await transportationService.getAll('transportationMarkers');
  final filtered = markers.where((m) => m.vehicleType.toLowerCase() == 'sikad');
  // same min-distance pattern as _findNearestHabal
  ...
}
```

---

#### Fix 3 — add multimodal walking penalty (slope = 1.5)

Add a separate walking penalty for Walking and Sikad (not jeepney):

```dart
const walkPenaltyThreshold200m = 0.2;
double _walkingPenaltyMultimodal(double walk200m) {
  if (walk200m <= walkPenaltyThreshold200m) return 0.0;
  return (walk200m - walkPenaltyThreshold200m) * 1.5;
}
```

---

#### Fix 4 — `_setupMediumDistanceRoute` — accurate jeepney scoring

**Replace** the current straight-line jeepney scoring block with one that calls `_getJeepneyRoutes` and reads the actual distances from the result, **mirroring the logic already in `_setupJeepneyRouteWithPolylines`**:

```dart
// NEW: accurate jeepney scoring using actual route data
if (canUseJeepney) {
  try {
    jeepneyResult = await _getJeepneyRoutes(userLocation, destination);
    final routes = jeepneyResult["routes"] as List<JeepneyRoute>;
    final type = jeepneyResult["type"] as String;
    final firstRoute = routes[0];

    final startPoint = _findNearestPoint(firstRoute.latLngPoints, userLocation);
    final walkToJeepney = calculateDistance(userLocation → startPoint);

    double rideDist, totalFare;
    String scoreMode;

    if (type == "single") {
      final nearestToDest = _findNearestPoint(firstRoute.latLngPoints, destination);
      rideDist = calculateDistance(startPoint → nearestToDest);
      totalFare = calculateJeepneyFare(rideDist);
      scoreMode = "jeepney";
    } else {
      // double ride — use transferPointA/B
      final tA = jeepneyResult["transferPointA"] as LatLng;
      final tB = jeepneyResult["transferPointB"] as LatLng;
      final secondRoute = routes[1];
      final nearestToDest = _findNearestPoint(secondRoute.latLngPoints, destination);

      final legA = calculateDistance(startPoint → tA);
      final legB = calculateDistance(tB → nearestToDest);
      final walkFromB = calculateDistance(nearestToDest → destination);

      rideDist = legA + legB;
      totalFare = calculateJeepneyFare(legA) + calculateJeepneyFare(legB);
      scoreMode = "jeepney+jeepney";
    }

    final totalDist = walkToJeepney + rideDist;
    jeepneyScore = calculateRouteScore(totalDist, totalFare, mode: scoreMode);
  } catch (e) { ... }
}
```

Also **add Sikad scoring** to `_setupMediumDistanceRoute` (Sikad is suitable for short trips):

```dart
// NEW: Sikad option (only if distance <= 2km)
double sikadScore = double.infinity;
TransportationMarkers? nearestSikad;
final canUseSikad = _transportPreferences["sikad"] ?? false;
if (canUseSikad && tripDistance <= 2.0) {
  nearestSikad = await _findNearestSikad(userLocation);
  if (nearestSikad != null) {
    final walkToSikad = calculateDistance(userLocation → nearestSikad.latLng);
    final sikadRide = calculateDistance(nearestSikad.latLng → destination);
    if (sikadRide <= 2.0) {
      final fare = calculateSikadFare(sikadRide);
      final walkPenalty = _walkingPenaltyMultimodal(walkToSikad * 5);
      sikadScore =
          calculateRouteScore(walkToSikad + sikadRide, fare, mode: "sikad") +
          walkPenalty;
    }
  }
}
```

Add walking penalty to the walking option:

```dart
final walkingPenalty = _walkingPenaltyMultimodal(walkingDistance * 5);
final walkingScore =
    calculateRouteScore(walkingDistance, walkingFare, mode: "walking") +
    walkingPenalty;
```

Then include `sikadScore` in the best-option comparison.

---

#### Fix 5 — `_setupLongDistanceRoute` — accurate jeepney scoring + walking penalty

**Replace** the `jeepneyPickup`/`jeepneyDropoff` block with the same accurate approach as Fix 3 above. Specifically:

- Remove `jeepneyPickup` and `jeepneyDropoff` variables entirely
- Compute `startPoint`, `rideDist`, `totalFare`, `scoreMode` from `jeepneyResult` properly (single vs double)
- For double ride, sum `legA + transferWalk + legB` for total distance
- Use `jeepneyResult` already in scope when computing OPTION 2, 3, 4 to avoid double-fetching

Add walking penalty to the walking option:

```dart
final walkingPenalty = _walkingPenaltyMultimodal(tripDistance * 5);
final walkingScore =
  calculateRouteScore(tripDistance, 0.0, mode: "walking") + walkingPenalty;
```

> [!NOTE]
> Sikad is **not** added to `_setupLongDistanceRoute` because it has a 2km hard cap — long-distance trips (3+ km) can never use it.

---

#### Fix 6 — `_setupSikadRouteWithPolylines` (new method)

Add a dedicated sikad route setup method following the same pattern as `_setupHabalRouteWithPolylines`:

```dart
Future<void> _setupSikadRouteWithPolylines(
  LatLng userLocation,
  LatLng sikadLocation,
  LatLng destination,
) async {
  _tasks.clear();
  final sikadRide = calculateDistance(sikadLocation → destination);
  // Enforce 2km max (safety guard)
  if (sikadRide > 2.0) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    return;
  }
  final fare = calculateSikadFare(sikadRide);

  final userToSikad = await _fetchPolyline(userLocation, sikadLocation);
  final sikadToDest = await _fetchPolyline(sikadLocation, destination);

  setState(() {
    _polylines = {
      Polyline(polylineId: PolylineId("user_to_sikad"), color: Colors.purple,
               width: 6, points: userToSikad,
               patterns: [PatternItem.dash(20), PatternItem.gap(10)]),
      Polyline(polylineId: PolylineId("sikad_to_dest"), color: Colors.deepPurple,
               width: 6, points: sikadToDest),
    };
  });

  _tasks.addAll([
    { "title": "Walk to Sikad", "target": sikadLocation, "radius": 20.0,
      "shortDescription": "Walk to the nearest Sikad (₱${fare.toStringAsFixed(0)}).",
      "longDescription": "Head to the Sikad pickup point. Upcoming fare: ₱${fare.toStringAsFixed(0)} for ${sikadRide.toStringAsFixed(1)}km." },
    { "title": "Ride Sikad", "target": destination, "radius": 20.0,
      "shortDescription": "Ride the Sikad to your destination (₱${fare.toStringAsFixed(0)}).",
      "longDescription": "Take the Sikad directly to your destination. Fare: ₱${fare.toStringAsFixed(0)} for ${sikadRide.toStringAsFixed(1)}km." },
  ]);

  _currentTaskIndex = 0;
  _setCurrentTask();
  // animate camera ...
}
```

---

#### Fix 7 — Transport preferences dialog: enable Sikad UI

The `"sikad"` key is already in `_transportPreferences` and already has a toggle in the dialog. No change needed there.

---

#### Fix 8 — `_setupMediumDistanceRoute` best-option decision: add Sikad branch

```dart
if (sikadScore <= jeepneyScore && sikadScore <= habalScore && sikadScore <= walkingScore) {
  await _setupSikadRouteWithPolylines(userLocation, nearestSikad!.latLng, destination);
} else if (jeepneyScore <= walkingScore && jeepneyScore <= habalScore) {
  await _setupJeepneyRouteWithPolylines(userLocation, destination);
} else if (habalScore <= walkingScore) {
  await _setupHabalRouteWithPolylines(userLocation, nearestHabal!.latLng, destination);
} else {
  await _setupWalkingRoute(userLocation, destination);
}
```

---

## Verification Plan

### Score consistency check

- Pick a destination requiring a **double jeepney** ride
- Choose "Multimodal" → confirm debug log shows two separate fares summed, not one flat fare
- Confirm the selected route matches what `_setupJeepneyRouteWithPolylines` draws

### Sikad enforcement

- Destination < 2km away → Sikad should appear as option if enabled in prefs
- Destination > 2km away → Sikad must be excluded from scoring (score stays `infinity`)

### Fare formula verification

| Distance | Expected Fare             |
| -------- | ------------------------- |
| 0.5 km   | ₱10                       |
| 1.0 km   | ₱10                       |
| 1.5 km   | ₱20 (1 extra 500m block)  |
| 2.0 km   | ₱30 (2 extra 500m blocks) |

> [!IMPORTANT]
> The existing `_setupHabalToJeepneyRoute` also does simplified jeepney scoring internally. That function should also get the same treatment (Fix 4-equivalent) but is lower priority since it's only reached for the Habal+Jeepney combo path.
