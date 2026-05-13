import http.server
import json
import os
import threading
import unittest
import webbrowser
from pathlib import Path

from android.app.src.main.python.routing import OSRM_DEFAULT_BASE_URL, calculate_route


class TestCalculateRoute(unittest.TestCase):

    OSRM_URL = os.environ.get("OSRM_BASE_URL", OSRM_DEFAULT_BASE_URL)
    _viewer_cases: list = []

    @classmethod
    def setUpClass(cls):
        cls._viewer_cases = []

    @classmethod
    def tearDownClass(cls):
        if cls._viewer_cases:
            _build_viewer(cls._viewer_cases, "route_viewer.html")
            _serve_and_open("route_viewer.html")

    def _parse(self, result_json: str) -> dict:
        return json.loads(result_json)

    def _run_and_track(self, label: str, *args, **kwargs) -> dict:
        result_json = calculate_route(*args, **kwargs)
        data = json.loads(result_json)
        if data["status"] == "success":
            self.__class__._viewer_cases.append({"label": label, "result": result_json})
        return data

    def test_short_walk(self):
        data = self._run_and_track("short walk — city centre", 41.9981, 21.4254, 41.9965, 21.4314, mode="walking")
        self.assertEqual(data["status"], "success")
        self.assertEqual(data["route"]["mode"], "walking")
        self.assertGreater(data["route"]["total_distance_meters"], 0)
        self.assertGreater(data["route"]["estimated_duration_seconds"], 0)
        self.assertGreaterEqual(len(data["route"]["polyline"]), 2)
        self.assertFalse(data["route"]["map_matched"])

    def test_short_drive(self):
        data = self._run_and_track("short drive — city centre", 41.9981, 21.4254, 41.9965, 21.4314, mode="driving")
        self.assertEqual(data["status"], "success")
        self.assertEqual(data["route"]["mode"], "driving")
        self.assertGreater(data["route"]["total_distance_meters"], 0)
        self.assertGreater(data["route"]["estimated_duration_seconds"], 0)
        self.assertGreaterEqual(len(data["route"]["polyline"]), 2)
        self.assertFalse(data["route"]["map_matched"])

    def test_longer_walk_with_map_matching(self):
        data = self._run_and_track(
            "longer walk — cross district",
            41.9981, 21.4254, 41.9935, 21.4112,
            mode="walking",
            osrm_base_url=self.OSRM_URL,
            map_matching=True,
        )
        self.assertEqual(data["status"], "success")
        self.assertGreaterEqual(len(data["route"]["polyline"]), 2)

    def test_longer_walk_least_curved(self):
        data = self._run_and_track(
            "longer walk — cross district",
            41.9981, 21.4254, 41.9935, 21.4112,
            mode="walking",
            use_curvature=True,
            curvature_weight=0.3,
            osrm_base_url=self.OSRM_URL,
            map_matching=True,
        )
        self.assertEqual(data["status"], "success")
        self.assertGreaterEqual(len(data["route"]["polyline"]), 2)

    def test_longer_drive_with_map_matching(self):
        data = self._run_and_track(
            "longer drive — cross district",
            41.9981, 21.4254, 41.986706, 21.427359,
            mode="driving",
            osrm_base_url=self.OSRM_URL,
            map_matching=True,
        )
        self.assertEqual(data["status"], "success")
        self.assertGreaterEqual(len(data["route"]["polyline"]), 2)

    def test_longer_drive_least_curved(self):
        data = self._run_and_track(
            "longer drive — cross district",
            41.9981, 21.4254, 41.986706, 21.427359,
            mode="driving",
            use_curvature=True,
            curvature_weight=0.3,
            osrm_base_url=self.OSRM_URL,
            map_matching=True,
        )
        self.assertEqual(data["status"], "success")
        self.assertGreaterEqual(len(data["route"]["polyline"]), 2)

    def test_same_origin_and_destination(self):
        data = self._parse(calculate_route(41.9981, 21.4254, 41.9981, 21.4254, mode="driving"))
        self.assertEqual(data["status"], "error")
        self.assertEqual(data["error"], "no_path_found")

    def test_invalid_latitude(self):
        data = self._parse(calculate_route(999, 21.4, 41.9, 21.5, mode="walking"))
        self.assertEqual(data["status"], "error")
        self.assertEqual(data["error"], "invalid_coordinates")

    def test_invalid_longitude(self):
        data = self._parse(calculate_route(41.9, 999, 41.5, 21.5, mode="walking"))
        self.assertEqual(data["status"], "error")
        self.assertEqual(data["error"], "invalid_coordinates")

    def test_none_coordinates(self):
        data = self._parse(calculate_route(None, 21.4254, 41.9965, 21.4314, mode="driving"))
        self.assertEqual(data["status"], "error")
        self.assertEqual(data["error"], "invalid_coordinates")

    def test_response_has_bounds(self):
        data = self._run_and_track("bounds check — drive", 41.9981, 21.4254, 41.9965, 21.4314, mode="driving")
        self.assertEqual(data["status"], "success")
        bounds = data["bounds"]
        self.assertIn("north", bounds)
        self.assertIn("south", bounds)
        self.assertIn("east", bounds)
        self.assertIn("west", bounds)
        self.assertGreaterEqual(bounds["north"], bounds["south"])
        self.assertGreaterEqual(bounds["east"], bounds["west"])

    def test_polyline_coords_are_valid(self):
        data = self._run_and_track("polyline validity — walk", 41.9981, 21.4254, 41.9965, 21.4314, mode="walking")
        self.assertEqual(data["status"], "success")
        for point in data["route"]["polyline"]:
            self.assertIn("lat", point)
            self.assertIn("lng", point)
            self.assertTrue(-90 <= point["lat"] <= 90)
            self.assertTrue(-180 <= point["lng"] <= 180)

    def test_map_matched_false_without_flag(self):
        data = self._run_and_track("map_matched flag — drive", 41.9981, 21.4254, 41.9965, 21.4314, mode="driving")
        self.assertFalse(data["route"]["map_matched"])


def _build_viewer(test_cases: list, output_path: str) -> None:
    route_features = []
    for tc in test_cases:
        data = json.loads(tc["result"])
        if data["status"] != "success":
            continue

        polyline = data["route"]["polyline"]
        coords = [[p["lng"], p["lat"]] for p in polyline]
        origin = coords[0]
        dest = coords[-1]
        mode = data["route"]["mode"]
        dist_km = data["route"]["total_distance_meters"] / 1000
        mins = data["route"]["estimated_duration_seconds"] // 60
        secs = data["route"]["estimated_duration_seconds"] % 60
        label = tc["label"]

        route_features.append({
            "type": "Feature",
            "properties": {
                "label": label,
                "mode": mode,
                "distance": f"{dist_km:.2f} km",
                "duration": f"{mins}m {secs:02d}s",
                "color": "#2563eb" if mode == "driving" else "#16a34a",
            },
            "geometry": {"type": "LineString", "coordinates": coords},
        })
        route_features.append({
            "type": "Feature",
            "properties": {"type": "origin", "label": label},
            "geometry": {"type": "Point", "coordinates": origin},
        })
        route_features.append({
            "type": "Feature",
            "properties": {"type": "destination", "label": label},
            "geometry": {"type": "Point", "coordinates": dest},
        })

    geojson = json.dumps({"type": "FeatureCollection", "features": route_features})

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>routing.py — test routes</title>
<link href="https://unpkg.com/maplibre-gl@4.5.0/dist/maplibre-gl.css" rel="stylesheet">
<script src="https://unpkg.com/maplibre-gl@4.5.0/dist/maplibre-gl.js"></script>
<style>
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: system-ui, sans-serif; background: #0f1117; color: #e2e8f0; height: 100dvh; display: flex; flex-direction: column; }}
  header {{ padding: 12px 16px; background: #1a1d27; border-bottom: 1px solid #2d3148; display: flex; align-items: center; gap: 12px; flex-shrink: 0; }}
  header h1 {{ font-size: 14px; font-weight: 600; letter-spacing: 0.02em; color: #f1f5f9; }}
  header span {{ font-size: 12px; color: #64748b; }}
  #map {{ flex: 1; }}
  .legend {{ position: absolute; bottom: 28px; left: 12px; background: rgba(15,17,23,0.92); backdrop-filter: blur(8px); border: 1px solid #2d3148; border-radius: 8px; padding: 10px 14px; font-size: 12px; line-height: 1.8; z-index: 10; }}
  .legend-row {{ display: flex; align-items: center; gap: 8px; }}
  .swatch {{ width: 24px; height: 4px; border-radius: 2px; flex-shrink: 0; }}
  .maplibregl-popup-content {{ background: #1a1d27; color: #e2e8f0; border: 1px solid #2d3148; border-radius: 8px; font-size: 13px; padding: 10px 14px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); }}
  .maplibregl-popup-tip {{ border-top-color: #1a1d27 !important; }}
  .popup-label {{ font-weight: 600; margin-bottom: 4px; color: #f1f5f9; }}
  .popup-meta {{ color: #94a3b8; }}
</style>
</head>
<body>
<header>
  <h1>routing.py — test routes</h1>
  <span id="route-count"></span>
</header>
<div id="map"></div>
<div class="legend">
  <div class="legend-row"><div class="swatch" style="background:#2563eb"></div> driving</div>
  <div class="legend-row"><div class="swatch" style="background:#16a34a"></div> walking</div>
  <div class="legend-row"><div style="width:10px;height:10px;border-radius:50%;background:#f59e0b;flex-shrink:0"></div> origin</div>
  <div class="legend-row"><div style="width:10px;height:10px;border-radius:50%;background:#ef4444;flex-shrink:0"></div> destination</div>
</div>
<script>
const geojson = {geojson};
const lines = geojson.features.filter(f => f.geometry.type === "LineString");
const origins = geojson.features.filter(f => f.properties.type === "origin");
const dests = geojson.features.filter(f => f.properties.type === "destination");

document.getElementById("route-count").textContent =
  lines.length + " route" + (lines.length !== 1 ? "s" : "");

const allCoords = lines.flatMap(f => f.geometry.coordinates);
const lngs = allCoords.map(c => c[0]);
const lats = allCoords.map(c => c[1]);
const bounds = [
  [Math.min(...lngs) - 0.005, Math.min(...lats) - 0.005],
  [Math.max(...lngs) + 0.005, Math.max(...lats) + 0.005],
];

const map = new maplibregl.Map({{
  container: "map",
  style: {{
    version: 8,
    sources: {{
      osm: {{
        type: "raster",
        tiles: ["https://tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png"],
        tileSize: 256,
        attribution: "© <a href='https://www.openstreetmap.org/copyright'>OpenStreetMap</a> contributors",
        maxzoom: 19,
      }},
    }},
    layers: [{{ id: "osm-tiles", type: "raster", source: "osm" }}],
  }},
  bounds,
  fitBoundsOptions: {{ padding: 60 }},
}});

map.addControl(new maplibregl.NavigationControl(), "top-right");

map.on("load", () => {{
  map.addSource("routes", {{ type: "geojson", data: {{ type: "FeatureCollection", features: lines }} }});
  map.addSource("origins", {{ type: "geojson", data: {{ type: "FeatureCollection", features: origins }} }});
  map.addSource("dests", {{ type: "geojson", data: {{ type: "FeatureCollection", features: dests }} }});

  map.addLayer({{
    id: "routes-casing",
    type: "line",
    source: "routes",
    layout: {{ "line-join": "round", "line-cap": "round" }},
    paint: {{ "line-color": "#000", "line-width": 6, "line-opacity": 0.3 }},
  }});

  map.addLayer({{
    id: "routes-fill",
    type: "line",
    source: "routes",
    layout: {{ "line-join": "round", "line-cap": "round" }},
    paint: {{ "line-color": ["get", "color"], "line-width": 4 }},
  }});

  map.addLayer({{
    id: "origins-layer",
    type: "circle",
    source: "origins",
    paint: {{
      "circle-radius": 7,
      "circle-color": "#f59e0b",
      "circle-stroke-width": 2,
      "circle-stroke-color": "#fff",
    }},
  }});

  map.addLayer({{
    id: "dests-layer",
    type: "circle",
    source: "dests",
    paint: {{
      "circle-radius": 7,
      "circle-color": "#ef4444",
      "circle-stroke-width": 2,
      "circle-stroke-color": "#fff",
    }},
  }});

  map.on("click", "routes-fill", (e) => {{
    const p = e.features[0].properties;
    new maplibregl.Popup()
      .setLngLat(e.lngLat)
      .setHTML(
        `<div class="popup-label">${{p.label}}</div>` +
        `<div class="popup-meta">mode: ${{p.mode}}<br>distance: ${{p.distance}}<br>duration: ${{p.duration}}</div>`
      )
      .addTo(map);
  }});

  map.on("mouseenter", "routes-fill", () => {{ map.getCanvas().style.cursor = "pointer"; }});
  map.on("mouseleave", "routes-fill", () => {{ map.getCanvas().style.cursor = ""; }});
}});
</script>
</body>
</html>"""

    Path(output_path).write_text(html, encoding="utf-8")
    print(f"[viewer] written → {output_path}")


def _serve_and_open(html_path: str, port: int = 8700) -> None:
    directory = str(Path(html_path).parent.resolve())
    filename = Path(html_path).name

    class _QuietHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", port), _QuietHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    url = f"http://127.0.0.1:{port}/{filename}"
    print(f"[viewer] serving at {url}  (Ctrl-C to stop)")
    webbrowser.open(url)

    try:
        thread.join()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    OSRM_URL = os.environ.get("OSRM_BASE_URL", OSRM_DEFAULT_BASE_URL)

    viewer_cases = [
        {
            "label": "short walk — city centre",
            "args": (41.9981, 21.4254, 41.9965, 21.4314),
            "kwargs": {"mode": "walking"},
        },
        {
            "label": "short drive — city centre",
            "args": (41.9981, 21.4254, 41.9965, 21.4314),
            "kwargs": {"mode": "driving"},
        },
        {
            "label": "longer walk — cross district",
            "args": (41.9981, 21.4254, 41.9935, 21.4112),
            "kwargs": {"mode": "walking", "osrm_base_url": OSRM_URL, "map_matching": True},
        },
        {
            "label": "longer walk — cross district",
            "args": (41.9981, 21.4254, 41.9935, 21.4112),
            "kwargs": {"mode": "walking", "use_curvature": True, "curvature_weight": 0.3, "osrm_base_url": OSRM_URL, "map_matching": True},
        },
        {
            "label": "longer drive — cross district",
            "args": (41.9981, 21.4254, 41.986706, 21.427359),
            "kwargs": {"mode": "driving", "osrm_base_url": OSRM_URL, "map_matching": True},
        },
        {
            "label": "longer drive — cross district",
            "args": (41.9981, 21.4254, 41.986706, 21.427359),
            "kwargs": {"mode": "driving", "use_curvature": True, "curvature_weight": 0.3, "osrm_base_url": OSRM_URL, "map_matching": True},
        },
    ]

    for tc in viewer_cases:
        tc["result"] = calculate_route(*tc["args"], **tc["kwargs"])

    _build_viewer(viewer_cases, "route_viewer.html")
    _serve_and_open("route_viewer.html")
