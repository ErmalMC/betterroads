# BetterRoads

A Flutter navigation app that finds the smoothest paths by balancing distance with road curvature. Perfect for motion sickness prevention, fuel efficiency, and comfortable driving.

**How it works:**
- Each road segment gets a curvature score based on turn angles
- Routes are weighted: 70% distance + 30% curvature penalty
- The algorithm prefers straighter highways over winding local roads
- Result: Far fewer turns, much smoother ride, slightly longer distance

## Features

### Smart Routing
- **Curvature-aware pathfinding** - Finds the straightest viable route
- **Driving & Walking modes** - Different speeds and road priorities
- **Real-time recalculation** - Switch modes and instantly see new routes
- **Map matching** - Routes snap precisely to actual roads

### Location Input
- **Address search** - Powered by Photon API with autocomplete suggestions
- **Current location** - One tap to set start point to your GPS position
- **Map tapping** - Tap anywhere to set start or destination points
- **Coordinate entry** - Manual input for precise locations (e.g., "41.9981, 21.4254")
- **Swap button** - Exchange start and destination instantly

### Map Experience
- **OpenStreetMap tiles** - Free, detailed global maps
- **Live location tracking** - Real-time position with pulsing blue dot
- **Follow mode toggle** - Auto-follow your movement or freely explore
- **Route visualization** - Clear blue polyline showing your path
- **Interactive markers** - Green start pin, red destination flag

### Route Information
- **Distance display** - Shows total route length
- **Time estimation** - Based on driving/walking speeds
- **Persistent panel** - Route info stays visible while navigating
- **Loading states** - Visual feedback during route calculation


## Installation

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart (>=3.0.0)
- Android Studio / Xcode for emulation

### Setup

1. **Clone the repository**
`git clone https://github.com/yourusername/better-roads.git
cd better-roads`


2. **Install flutter dependencies**
  `flutter pub get`

3. **Run the app**
   `flutter run`

## Project Structure

```
lib/
├── helpers/
    ├── route_progress.dart       # Helper class for tracking progress
├── models/
    ├── location.dart             # Location data model
    └── route_metrics.dart        # Distance/duration parsing
├── screens/
│   └── map_screen.dart           # Main map UI with all logic
├── 
├── services/
│   ├── route_api_service.dart    # Backend API communication
│   └── photon_service.dart       # Location search (OpenStreetMap)
└── widgets/
    ├── route_info_panel.dart     # Bottom panel showing route stats
    └── search_panel.dart         # Search panel with location suggestions.
   ```

