from datetime import datetime, timezone, timedelta
import json
import xml.etree.ElementTree as ET
from xml.dom import minidom

def format_iso_utc(dt: datetime) -> str:
  dt_utc = dt.astimezone(timezone.utc)
  return dt_utc.strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"

def interpolate_points(start: dict[str, any], end: dict[str, any], num_steps: int, start_time: datetime, time_step_seconds: int | float) -> list[dict[str, any]]:
    points = []
    for i in range(num_steps):
        fraction = i / num_steps
        lat = start["latitude"] + (end["latitude"] - start["latitude"]) * fraction
        lon = start["longitude"] + (end["longitude"] - start["longitude"]) * fraction
        
        point_time = start_time + timedelta(seconds=i * time_step_seconds)
        
        points.append({
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "timestamp": format_iso_utc(point_time),
            "timezone_offset_minutes": 540
        })
    return points

def export_to_json(route_data: dict[str, any], filename="logical_route_export.json"):
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(route_data, f, indent=2)
    print(f"Successfully generated JSON file: {filename}")

def export_to_gpx(route_data: dict[str, any], filename="logical_route_export.gpx"):
    gpx = ET.Element("gpx", {
        "version": "1.1",
        "creator": "My Location Record",
        "xmlns": "http://www.topografix.com/GPX/1/1"
    })
    
    trk = ET.SubElement(gpx, "trk")
    
    name_el = ET.SubElement(trk, "name")
    name_el.text = route_data["name"]
    
    extensions_el = ET.SubElement(trk, "extensions")
    created_at_el = ET.SubElement(extensions_el, "created_at")
    created_at_el.text = route_data["created_at"]
    
    total_points_el = ET.SubElement(extensions_el, "total_points")
    total_points_el.text = str(route_data["total_points"])
    
    trkseg = ET.SubElement(trk, "trkseg")
    
    for p in route_data["points"]:
        trkpt = ET.SubElement(trkseg, "trkpt", {
            "lat": str(p["latitude"]),
            "lon": str(p["longitude"])
        })
        
        time_el = ET.SubElement(trkpt, "time")
        time_el.text = p["timestamp"]
        
        pt_extensions = ET.SubElement(trkpt, "extensions")
        tz_el = ET.SubElement(pt_extensions, "timezone_offset_minutes")
        tz_el.text = str(p["timezone_offset_minutes"])
        
    rough_string = ET.tostring(gpx, encoding="utf-8")
    reparsed = minidom.parseString(rough_string)
    pretty_xml = reparsed.toprettyxml(indent="  ")
    
    cleaned_xml = "\n".join([line for line in pretty_xml.split("\n") if line.strip()])

    with open(filename, "w", encoding="utf-8") as f:
        f.write(cleaned_xml)
        
    print(f"Successfully generated GPX file: {filename}")

def generate_logical_route():
    waypoints = [
        # Hokkaidou Shinkansen
        {"name": "Shin-Hakodate-Hokuto", "latitude": 41.9047, "longitude": 140.6483},
        {"name": "Kikonai", "latitude": 41.6781, "longitude": 140.4344},
        {"name": "Okutsugaru-Imabetsu", "latitude": 41.1444, "longitude": 140.5147},
        # Touhoku Shinkansen
        {"name": "Shin-Aomori", "latitude": 40.827500, "longitude": 140.691389},
        {"name": "Shichinohe-Towada", "latitude": 40.713889, "longitude": 141.211944},
        {"name": "Hachinohe", "latitude": 40.510833, "longitude": 141.491389},
        {"name": "Ninohe", "latitude": 40.264444, "longitude": 141.303333},
        {"name": "Iwate-Numakunai", "latitude": 40.016389, "longitude": 141.258056},
        {"name": "Morioka", "latitude": 39.700278, "longitude": 141.137500},
        {"name": "Shin-Hanamaki", "latitude": 39.395833, "longitude": 141.185556},
        {"name": "Kitakami", "latitude": 39.284167, "longitude": 141.116389},
        {"name": "Mizusawa-Esashi", "latitude": 39.141667, "longitude": 141.171389},
        {"name": "Ichinoseki", "latitude": 38.927500, "longitude": 141.144444},
        {"name": "Kurikoma-Kogen", "latitude": 38.775833, "longitude": 141.059444},
        {"name": "Furukawa", "latitude": 38.570582, "longitude": 140.967722},
        {"name": "Sendai", "latitude": 38.260278, "longitude": 140.882222},
        {"name": "Shiroishi-Zao", "latitude": 38.074722, "longitude": 140.647222},
        {"name": "Fukushima", "latitude": 37.754167, "longitude": 140.462500},
        {"name": "Koriyama", "latitude": 37.398333, "longitude": 140.388889},
        {"name": "Shin-Shirakawa", "latitude": 37.126111, "longitude": 140.201389},
        {"name": "Nasushiobara", "latitude": 36.874444, "longitude": 139.987778},
        {"name": "Utsunomiya", "latitude": 36.559167, "longitude": 139.898528},
        {"name": "Oyama", "latitude": 36.311667, "longitude": 139.805556},
        {"name": "Omiya", "latitude": 35.906111, "longitude": 139.623333},
        {"name": "Ueno", "latitude": 35.713768, "longitude": 139.777254},
        # Toukaidou Shinkansen
        {"name": "Tokyo", "latitude": 35.681236, "longitude": 139.767125},
        {"name": "Shinagawa", "latitude": 35.628471, "longitude": 139.738760},
        {"name": "Shin-Yokohama", "latitude": 35.507805, "longitude": 139.617664},
        {"name": "Odawara", "latitude": 35.256242, "longitude": 139.154949},
        {"name": "Atami", "latitude": 35.101859, "longitude": 139.077271},
        {"name": "Mishima", "latitude": 35.126081, "longitude": 138.911048},
        {"name": "Shin-Fuji", "latitude": 35.154089, "longitude": 138.653453},
        {"name": "Shizuoka", "latitude": 34.972322, "longitude": 138.388836},
        {"name": "Kakegawa", "latitude": 34.769974, "longitude": 138.014299},
        {"name": "Hamamatsu", "latitude": 34.703478, "longitude": 137.734990},
        {"name": "Toyohashi", "latitude": 34.763261, "longitude": 137.382433},
        {"name": "Mikawa-Anjo", "latitude": 34.978873, "longitude": 137.060155},
        {"name": "Nagoya", "latitude": 35.170915, "longitude": 136.881537},
        {"name": "Gifu-Hashima", "latitude": 35.316881, "longitude": 136.685338},
        {"name": "Maibara", "latitude": 35.314205, "longitude": 136.290278},
        {"name": "Kyoto", "latitude": 34.985849, "longitude": 135.758767},
        {"name": "Shin-Osaka", "latitude": 34.733479, "longitude": 135.500108},
        # Sanyou Shinkansen
        {"name": "Shin-Kobe", "latitude": 34.707797, "longitude": 135.193635},
        {"name": "Nishi-Akashi", "latitude": 34.647573, "longitude": 134.996131},
        {"name": "Himeji", "latitude": 34.828519, "longitude": 134.690858},
        {"name": "Aioi", "latitude": 34.832967, "longitude": 134.469794},
        {"name": "Okayama", "latitude": 34.665727, "longitude": 133.919076},
        {"name": "Shin-Kurashiki", "latitude": 34.570685, "longitude": 133.714541},
        {"name": "Fukuyama", "latitude": 34.485746, "longitude": 133.364403},
        {"name": "Shin-Onomichi", "latitude": 34.421528, "longitude": 133.197944},
        {"name": "Mihara", "latitude": 34.403597, "longitude": 133.082717},
        {"name": "Higashi-Hiroshima", "latitude": 34.425883, "longitude": 132.735167},
        {"name": "Hiroshima", "latitude": 34.397683, "longitude": 132.475458},
        {"name": "Shin-Iwakuni", "latitude": 34.156108, "longitude": 132.179378},
        {"name": "Tokuyama", "latitude": 34.060133, "longitude": 131.802808},
        {"name": "Shin-Yamaguchi", "latitude": 34.095033, "longitude": 131.393450},
        {"name": "Asa", "latitude": 34.049444, "longitude": 131.157500},
        {"name": "Shin-Shimonoseki", "latitude": 34.004467, "longitude": 130.957247},
        {"name": "Kokura", "latitude": 33.886014, "longitude": 130.881258},
        {"name": "Hakata", "latitude": 33.590197, "longitude": 130.420658},
        # Kyuushuu Shinkansen
        {"name": "Shin-Tosu", "latitude": 33.374189, "longitude": 130.518625},
        {"name": "Kurume", "latitude": 33.319522, "longitude": 130.513525},
        {"name": "Chikugo-Funagoya", "latitude": 33.208103, "longitude": 130.505500},
        {"name": "Shin-Omuta", "latitude": 33.075489, "longitude": 130.504269},
        {"name": "Shin-Tamana", "latitude": 32.930419, "longitude": 130.612500},
        {"name": "Kumamoto", "latitude": 32.789853, "longitude": 130.688842},
        {"name": "Shin-Yatsushiro", "latitude": 32.508569, "longitude": 130.694697},
        {"name": "Shin-Minamata", "latitude": 32.213194, "longitude": 130.407472},
        {"name": "Izumi", "latitude": 32.091044, "longitude": 130.354336},
        {"name": "Sendai", "latitude": 31.828389, "longitude": 130.312958},
        {"name": "Kagoshima-Chuo", "latitude": 31.585403, "longitude": 130.543206},
    ]
    
    current_time = datetime(2020, 1, 1, 17, 0, 0, 0, timezone.utc)
    all_points = []
    steps_per_segment = 10 
    interval_seconds = 15  
    
    for i in range(len(waypoints) - 1):
        start = waypoints[i]
        end = waypoints[i+1]
        
        segment_points = interpolate_points(
            start, end, 
            num_steps=steps_per_segment, 
            start_time=current_time, 
            time_step_seconds=interval_seconds
        )
        
        all_points.extend(segment_points)
        current_time += timedelta(seconds=steps_per_segment * interval_seconds)

    route_data = {
        "created_at": format_iso_utc(datetime.now(timezone.utc)),
        "name": "Simulated Walking Route",
        "total_points": len(all_points),
        "points": all_points
    }

    export_to_json(route_data)
    export_to_gpx(route_data)

if __name__ == "__main__":
    generate_logical_route()