from fastapi import FastAPI
import joblib
import pandas as pd
import requests
import threading
import time
import os
import psycopg2
from network import FEATURE_COLS, decode_class
from calib_baseline import BaselineManager


SERVER_API = os.getenv("SERVER_API", "http://api:3000/api")
AI_EMAIL = os.getenv("AI_EMAIL")
AI_PASSWORD = os.getenv("AI_PASSWORD")
POLL_SECONDS = int(os.getenv("POLL_SECONDS", "5"))
PG_HOST = os.getenv("POSTGRES_HOST", "postgres")
PG_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
PG_DB = os.getenv("POSTGRES_DB", "smartair")
PG_USER = os.getenv("POSTGRES_USER", "smartair")
PG_PASSWORD = os.getenv("POSTGRES_PASSWORD")
warning_count_by_device = {}
CONFIRM_REQUIRED = 3
last_control_by_device = {}
if not AI_EMAIL or not AI_PASSWORD:
    raise RuntimeError("Missing AI_EMAIL or AI_PASSWORD")

app = FastAPI()

model = joblib.load("smart_air_model_v3.pkl")

# Baseline riêng cho từng device
baselines = {}

# Lưu timestamp cuối cùng đã xử lý theo từng device
last_ts_by_device = {}


def get_baseline(device_id):
    if device_id in baselines:
        return baselines[device_id]

    bm = BaselineManager(calibration_size=30)

    saved = load_baseline_from_db(device_id)

    if saved:
        bm.long_base = saved.copy()
        bm.short_base = saved.copy()
        bm.is_calibrated = True
        print(f"[{device_id}] Loaded baseline from DB: {saved}", flush=True)

    baselines[device_id] = bm
    return bm


def login():
    res = requests.post(
        f"{SERVER_API}/auth/login",
        json={
            "email": AI_EMAIL,
            "password": AI_PASSWORD
        },
        timeout=5
    )
    res.raise_for_status()
    return res.json()["accessToken"]


def get_devices(token):
    res = requests.get(
        f"{SERVER_API}/devices",
        headers={"Authorization": f"Bearer {token}"},
        timeout=5
    )
    res.raise_for_status()
    return res.json()


def get_latest_telemetry(token, device_id):
    res = requests.get(
        f"{SERVER_API}/devices/{device_id}/telemetry?limit=1",
        headers={"Authorization": f"Bearer {token}"},
        timeout=5
    )
    res.raise_for_status()
    data = res.json()

    if not data:
        return None

    return data[0]


def set_relay(token, device_id, channel, state):
    res = requests.post(
        f"{SERVER_API}/devices/{device_id}/relay/{channel}",
        headers={"Authorization": f"Bearer {token}"},
        json={"state": bool(state)},
        timeout=5
    )
    res.raise_for_status()
    return res.json()


def run_prediction(device_id, sensor):
    required = ["temperature", "humidity", "co_ppm", "no2_ppm"]

    for key in required:
        if key not in sensor or sensor[key] is None:
            return {"error": f"missing field: {key}"}

    clean_sensor = {
        "temperature": float(sensor["temperature"]),
        "humidity": float(sensor["humidity"]),
        "co_ppm": float(sensor["co_ppm"]),
        "no2_ppm": float(sensor["no2_ppm"]),
    }

    baseline = get_baseline(device_id)

    if not baseline.is_calibrated:
        baseline.add_calibration_sample(clean_sensor)

        if baseline.is_calibrated:
            save_baseline_to_db(device_id, baseline.long_base)
            print(f"[{device_id}] Baseline saved to DB: {baseline.long_base}", flush=True)

        return {
            "device_id": device_id,
            "status": "calibrating",
            "samples": len(baseline.buffer),
            "required": baseline.calibration_size
        }

    features = baseline.make_feature_vector(clean_sensor)
    X = pd.DataFrame([features], columns=FEATURE_COLS)

    class_id = int(model.predict(X)[0])
    result = decode_class(class_id)

    baseline.update_baseline(clean_sensor, class_id)
    save_baseline_to_db(device_id, baseline.long_base)
    return {
        "device_id": device_id,
        "class_id": class_id,
        "meaning": result["meaning"],
        "fan": result["fan"],
        "light": result["light"],
        "buzzer": result["buzzer"],
        "features": features
    }


def apply_control(token, device_id, ai_result):
    if ai_result.get("status") == "calibrating":
        return

    if "error" in ai_result:
        return

    desired = {
        "fan": bool(ai_result["fan"]),
        "light": bool(ai_result["light"]),
        "buzzer": bool(ai_result["buzzer"]),
    }

    class_id = ai_result.get("class_id", 0)

    if class_id != 0:
        warning_count_by_device[device_id] = \
            warning_count_by_device.get(device_id, 0) + 1
    else:
        warning_count_by_device[device_id] = 0

    if class_id != 0 and \
    warning_count_by_device[device_id] < CONFIRM_REQUIRED:

        print(
            f"[{device_id}] Warning detected but waiting confirm "
            f"{warning_count_by_device[device_id]}/{CONFIRM_REQUIRED}",
            flush=True
        )
        return

    if last_control_by_device.get(device_id) == desired:
        print(f"[{device_id}] Control unchanged, skip", flush=True)
        return

    last_control_by_device[device_id] = desired

    r1 = set_relay(token, device_id, 1, desired["fan"])
    r2 = set_relay(token, device_id, 2, desired["light"])
    r3 = set_relay(token, device_id, 3, desired["buzzer"])

    print(f"[{device_id}] Control sent:", r1, r2, r3, flush=True)

def db_conn():
    return psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        dbname=PG_DB,
        user=PG_USER,
        password=PG_PASSWORD,
    )


def load_baseline_from_db(device_id):
    try:
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT temp_base, hum_base, co_base, no2_base
                    FROM ai_baselines
                    WHERE device_id = %s
                    """,
                    (device_id,)
                )
                row = cur.fetchone()

        if not row:
            return None

        return {
            "temp_base": float(row[0]),
            "hum_base": float(row[1]),
            "co_base": float(row[2]),
            "no2_base": float(row[3]),
        }

    except Exception as e:
        print(f"[{device_id}] Load baseline DB error: {e}", flush=True)
        return None


def save_baseline_to_db(device_id, baseline_values):
    try:
        with db_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO ai_baselines (
                        device_id,
                        temp_base,
                        hum_base,
                        co_base,
                        no2_base,
                        updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (device_id)
                    DO UPDATE SET
                        temp_base = EXCLUDED.temp_base,
                        hum_base = EXCLUDED.hum_base,
                        co_base = EXCLUDED.co_base,
                        no2_base = EXCLUDED.no2_base,
                        updated_at = NOW()
                    """,
                    (
                        device_id,
                        float(baseline_values["temp_base"]),
                        float(baseline_values["hum_base"]),
                        float(baseline_values["co_base"]),
                        float(baseline_values["no2_base"]),
                    )
                )

    except Exception as e:
        print(f"[{device_id}] Save baseline DB error: {e}", flush=True)
def telemetry_loop():
    token = None

    while True:
        try:
            if token is None:
                token = login()
                print("AI telemetry loop login OK", flush=True)

            devices = get_devices(token)

            if not devices:
                print("No devices found", flush=True)
                time.sleep(POLL_SECONDS)
                continue

            for device in devices:
                device_id = device["id"]

                telemetry = get_latest_telemetry(token, device_id)

                if telemetry is None:
                    print(f"[{device_id}] No telemetry yet", flush=True)
                    continue

                current_ts = telemetry["ts"]
                last_ts = last_ts_by_device.get(device_id)

                if current_ts == last_ts:
                    print(f"[{device_id}] No new telemetry", flush=True)
                    continue

                last_ts_by_device[device_id] = current_ts

                ai_result = run_prediction(device_id, telemetry)

                print(f"[{device_id}] Telemetry: {telemetry}", flush=True)
                print(f"[{device_id}] AI result: {ai_result}", flush=True)

                apply_control(token, device_id, ai_result)

        except requests.exceptions.HTTPError as e:
            print("HTTP error:", e, flush=True)
            token = None

        except Exception as e:
            print("Loop error:", e, flush=True)

        time.sleep(POLL_SECONDS)


@app.on_event("startup")
def startup_event():
    thread = threading.Thread(target=telemetry_loop, daemon=True)
    thread.start()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/predict")
def predict(sensor: dict):
    device_id = sensor.get("device_id", "manual-test")

    ai_result = run_prediction(device_id, sensor)

    if "device_id" in sensor:
        try:
            token = login()
            apply_control(token, device_id, ai_result)
        except Exception as e:
            ai_result["control_error"] = str(e)

    return ai_result