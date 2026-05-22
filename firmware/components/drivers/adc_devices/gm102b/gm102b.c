/**
 * @file gm102b.c
 * 
 * @brief Winsen GM-102B NO2 Gas Sensor driver implementation.
 * 
 * Copyright (C) 2026 MinhNhat & BaoViet
 *
 * Reads analog voltage from DFRobot SEN0574 breakout board via ADC1.
 * Converts voltage → resistance → Rs/R0 ratio → NO2 ppm via lookup table.
 *
 * NO2 characteristic: Rs INCREASES as NO2 concentration increases.
 * Rs/R0 > 1 indicates NO2 present (opposite of CO sensor behavior).
 */

#include "gm102b.h"
#include "adc_bus.h"

#include <math.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "gm102b";
static portMUX_TYPE s_state_lock = portMUX_INITIALIZER_UNLOCKED;

#define CHECK(x)                                                                     \
    do {                                                                             \
        esp_err_t __err = (x);                                                       \
        if (__err != ESP_OK) {                                                       \
            ESP_LOGE(TAG, "%s:%d (%s)", __FILE__, __LINE__, esp_err_to_name(__err)); \
            return __err;                                                            \
        }                                                                            \
    } while (0)

#define CHECK_ARG(VAL)                                                   \
    do {                                                                 \
        if (!(VAL)) {                                                    \
            ESP_LOGE(TAG, "%s:%d invalid argument", __FILE__, __LINE__); \
            return ESP_ERR_INVALID_ARG;                                  \
        }                                                                \
    } while (0)

/* ── Lookup table: Rs/R0 → NO2 ppm (from datasheet Fig.3) ─────────────── */
/* Rs/R0 INCREASES with NO2 concentration (monotonically increasing).       */

typedef struct {
    float ratio;
    float ppm;
} ratio_point_t;

static const ratio_point_t NO2_CURVE[] = {
    {1.00f, 0.0f},
    {1.50f, 0.5f},
    {2.00f, 1.0f},
    {2.50f, 2.0f},
    {3.00f, 3.0f},
    {3.50f, 4.0f},
    {4.00f, 5.0f},
    {4.50f, 7.0f},
    {5.00f, 10.0f},
};
static const int NO2_CURVE_LEN = sizeof(NO2_CURVE) / sizeof(NO2_CURVE[0]);

#define CALIBRATION_SAMPLES           20
#define CALIBRATION_DELAY_MS          50
#define CALIBRATION_MIN_VALID_SAMPLES ((CALIBRATION_SAMPLES * 3) / 4)

/**
 * @brief Linear interpolation between two points.
 */
static float lerp(float x1, float y1, float x2, float y2, float x)
{
    if (fabsf(x2 - x1) < 1e-6f)
        return y1;
    float t = (x - x1) / (x2 - x1);
    return y1 + t * (y2 - y1);
}

/**
 * @brief Convert Rs/R0 ratio to NO2 ppm using lookup + interpolation.
 *
 * NO2: ratio INCREASES as ppm increases (curve is monotonically increasing).
 */
static float ratio_to_ppm_no2(float ratio)
{
    /* Below baseline — no NO2 detected */
    if (ratio <= NO2_CURVE[0].ratio) {
        return 0.0f;
    }
    /* Above maximum ratio — clamp to max range */
    if (ratio >= NO2_CURVE[NO2_CURVE_LEN - 1].ratio) {
        return GM102B_NO2_PPM_MAX;
    }
    /* Find interval and interpolate (ratio is increasing in table) */
    for (int i = 0; i < NO2_CURVE_LEN - 1; i++) {
        if (ratio >= NO2_CURVE[i].ratio && ratio <= NO2_CURVE[i + 1].ratio) {
            return lerp(NO2_CURVE[i].ratio, NO2_CURVE[i].ppm, NO2_CURVE[i + 1].ratio, NO2_CURVE[i + 1].ppm, ratio);
        }
    }
    return 0.0f;
}

/**
 * @brief Calculate sensor resistance Rs from output voltage.
 *
 * Circuit: Vout = VC × RL / (Rs + RL)
 * Solving: Rs = RL × (VC - Vout) / Vout
 */
static float voltage_to_rs(float vout_v, float rl, float vc)
{
    if (vout_v < 0.001f)
        return rl * 1000.0f; /* Avoid division by zero */
    return rl * (vc - vout_v) / vout_v;
}

static void gm102b_get_calibration_state(gm102b_t *dev, float *r0, bool *calibrated)
{
    portENTER_CRITICAL(&s_state_lock);
    *r0 = dev->r0;
    *calibrated = dev->calibrated;
    portEXIT_CRITICAL(&s_state_lock);
}

static void gm102b_set_calibration_state(gm102b_t *dev, float r0, bool calibrated)
{
    portENTER_CRITICAL(&s_state_lock);
    dev->r0 = r0;
    dev->calibrated = calibrated;
    portEXIT_CRITICAL(&s_state_lock);
}

/* ── Public API ────────────────────────────────────────────────────────── */

esp_err_t gm102b_init(gm102b_t *dev, adc_channel_t channel, float rl, float vc)
{
    CHECK_ARG(dev && rl > 0 && vc > 0);

    dev->channel = channel;
    dev->rl = rl;
    dev->vc = vc;
    dev->r0 = 0.0f;
    dev->calibrated = false;

    CHECK(adc_bus_config_channel(channel, ADC_ATTEN_DB_12));

    ESP_LOGI(TAG, "NO2 sensor initialized on ADC1 channel %d (RL=%.0f ohm, VC=%.1fV)", (int)channel, rl, vc);
    return ESP_OK;
}

esp_err_t gm102b_calibrate(gm102b_t *dev)
{
    CHECK_ARG(dev);

    float rs_sum = 0.0f;
    int valid = 0;
    esp_err_t last_err = ESP_FAIL;

    ESP_LOGI(TAG, "Calibrating R0 in clean air (%d samples)...", CALIBRATION_SAMPLES);

    for (int i = 0; i < CALIBRATION_SAMPLES; i++) {
        int mv;
        esp_err_t err = adc_bus_read_voltage(dev->channel, &mv);
        if (err != ESP_OK) {
            last_err = err;
            ESP_LOGW(TAG, "Calibration sample %d/%d failed: %s", i + 1, CALIBRATION_SAMPLES, esp_err_to_name(err));
            continue;
        }

        float vout = (float)mv / 1000.0f;
        float rs = voltage_to_rs(vout, dev->rl, dev->vc);
        if (!isfinite(rs) || rs <= 0.0f) {
            last_err = ESP_ERR_INVALID_STATE;
            ESP_LOGW(TAG,
                     "Calibration sample %d/%d invalid: Vout=%.3fV produced Rs=%.3f ohm",
                     i + 1,
                     CALIBRATION_SAMPLES,
                     vout,
                     rs);
            continue;
        }
        rs_sum += rs;
        valid++;

        vTaskDelay(pdMS_TO_TICKS(CALIBRATION_DELAY_MS));
    }

    if (valid == 0) {
        ESP_LOGE(TAG, "Calibration failed — no valid readings");
        return last_err;
    }

    if (valid < CALIBRATION_MIN_VALID_SAMPLES) {
        ESP_LOGE(TAG,
                 "Calibration failed — insufficient valid readings (%d/%d, need at least %d)",
                 valid,
                 CALIBRATION_SAMPLES,
                 CALIBRATION_MIN_VALID_SAMPLES);
        return ESP_ERR_INVALID_STATE;
    }

    gm102b_set_calibration_state(dev, rs_sum / (float)valid, true);

    ESP_LOGI(TAG, "Calibration complete: R0 = %.0f ohm (%d samples)", dev->r0, valid);
    return ESP_OK;
}

esp_err_t gm102b_read(gm102b_t *dev, float *no2_ppm)
{
    CHECK_ARG(dev && no2_ppm);

    float r0;
    bool calibrated;
    gm102b_get_calibration_state(dev, &r0, &calibrated);

    if (!calibrated) {
        ESP_LOGW(TAG, "Sensor not calibrated — returning 0");
    }

    int mv;
    CHECK(adc_bus_read_voltage(dev->channel, &mv));

    float vout = (float)mv / 1000.0f;
    float rs = voltage_to_rs(vout, dev->rl, dev->vc);

    if (calibrated && r0 > 0) {
        float ratio = rs / r0;
        *no2_ppm = ratio_to_ppm_no2(ratio);
    } else {
        *no2_ppm = 0.0f;
    }

    return ESP_OK;
}

esp_err_t gm102b_read_ratio(gm102b_t *dev, float *ratio)
{
    CHECK_ARG(dev && ratio);

    float r0;
    bool calibrated;
    gm102b_get_calibration_state(dev, &r0, &calibrated);
    CHECK_ARG(calibrated && r0 > 0);

    int mv;
    CHECK(adc_bus_read_voltage(dev->channel, &mv));

    float vout = (float)mv / 1000.0f;
    float rs = voltage_to_rs(vout, dev->rl, dev->vc);
    *ratio = rs / r0;

    return ESP_OK;
}

esp_err_t gm102b_read_voltage(gm102b_t *dev, int *voltage_mv)
{
    CHECK_ARG(dev && voltage_mv);
    return adc_bus_read_voltage(dev->channel, voltage_mv);
}
