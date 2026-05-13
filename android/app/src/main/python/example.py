import json


def example_function(message):
    return f"Message received by Python: {message}"


def compute_route(
    start_latitude,
    start_longitude,
    destination_latitude,
    destination_longitude,
):
    first_midpoint = {
        "latitude": (start_latitude * 2 + destination_latitude) / 3,
        "longitude": (start_longitude * 2 + destination_longitude) / 3,
    }
    second_midpoint = {
        "latitude": (start_latitude + destination_latitude * 2) / 3,
        "longitude": (start_longitude + destination_longitude * 2) / 3,
    }

    return json.dumps(
        {
            "status": "ok",
            "start": {
                "latitude": start_latitude,
                "longitude": start_longitude,
            },
            "destination": {
                "latitude": destination_latitude,
                "longitude": destination_longitude,
            },
            "route_points": [
                {
                    "latitude": start_latitude,
                    "longitude": start_longitude,
                },
                first_midpoint,
                second_midpoint,
                {
                    "latitude": destination_latitude,
                    "longitude": destination_longitude,
                },
            ],
        }
    )
