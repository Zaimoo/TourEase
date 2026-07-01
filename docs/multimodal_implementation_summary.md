# Multimodal Implementation Summary

This document summarizes the changes applied to multimodal routing and Sikad support after the implementation plan.

## Scope

All changes were made in `lib/view/map_screen.dart` and focus on:

- Accurate jeepney scoring for multimodal medium/long routes
- Sikad scoring and routing support
- Walking penalties for multimodal options (Walking + Sikad)

## Detailed Changes

### 1) Sikad fare model

- Replaced placeholder fare with a formula-based fare.
- Rule: first 1.0 km is 10.0; each additional 0.5 km adds 10.0.
- At 2.0 km, total fare is 30.0.

### 2) Sikad normalization in route scoring

- Updated `calculateRouteScore` to use a max fare of 30.0 for `sikad`.
- This aligns scoring normalization with the new fare model.

### 3) Multimodal walking penalty (non-jeepney)

- Added `_walkingPenaltyMultimodal` used only for Walking and Sikad.
- Uses a threshold of 0.2 (200 m units) and a slope of 1.5.
- This is separate from the jeepney walking penalty logic.

### 4) Nearest Sikad helper

- Added `_findNearestSikad` to search `transportationMarkers` for `sikad`.
- Mirrors `_findNearestHabal` behavior.

### 5) Medium-distance multimodal scoring

#### Walking

- Walking score now includes `_walkingPenaltyMultimodal`.

#### Jeepney

- Scoring is based on `_getJeepneyRoutes` instead of straight-line distance.
- Single ride: pickup to nearest-to-destination point on Route A.
- Double ride: uses `transferPointA` and `transferPointB` and sums both legs.
- Fare is computed as the sum of leg fares.

#### Sikad

- Added Sikad scoring when total trip distance is <= 2.0 km.
- Applies walking penalty for the walk-to-sikad segment.

#### Selection

- Sikad is included in the best-option decision alongside Walking, Jeepney, and Habal.

### 6) Long-distance multimodal scoring

- Walking score includes `_walkingPenaltyMultimodal`.
- Jeepney scoring uses actual route data from `_getJeepneyRoutes`:
  - Single ride: pickup to dropoff on Route A.
  - Double ride: pickup to `transferPointA` + `transferPointB` to dropoff on Route B.
- Mixed modes (Walk+Jeepney+Habal and Habal+Jeepney) now use the updated jeepney distances and fare.

### 7) Sikad route setup

- Added `_setupSikadRouteWithPolylines`.
- Enforces a 2.0 km ride cap and warns if exceeded.
- Draws user-to-sikad (dashed) and sikad-to-destination polylines.
- Creates tasks for walking to Sikad and riding to destination.

## Behavior Notes

- Sikad only participates in medium-distance scoring when total trip <= 2.0 km.
- Walking penalties now affect Walking and Sikad scores but do not affect jeepney penalties.
- Jeepney multimodal scoring now matches the logic used by the dedicated Jeepney button.

## Files Changed

- `lib/view/map_screen.dart`

## Suggested Verification

- Medium-distance destination with Sikad enabled should show Sikad as a candidate.
- Double-jeepney destination in Multimodal should score using two legs and two fares.
- Walking should score worse for longer distances due to the new penalty.
