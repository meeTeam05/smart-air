/**
 * @file gm702b.c
 * @brief Winsen GM-702B CO Gas Sensor driver implementation.
 *
 * Reads analog voltage from DFRobot SEN0564 breakout board via ADC1.
 * Converts voltage → resistance → Rs/R0 ratio → CO ppm via lookup table.
 *
 * CO characteristic: Rs DECREASES as CO concentration increases.
 * Rs/R0 < 1 indicates CO present.
 */

#include "gm702b.h"
#include "adc_bus.h"

#include <math.h>
#include <esp_log.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

static const char *TAG = "gm702b";

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

/* ── Lookup table: Rs/R0 → CO ppm (from datasheet Fig.3) ──────────────── */
/* Log-log relationship. Points extracted from GM-702B characteristic curve. */

typedef struct {
    float ratio;
    float ppm;
} ratio_point_t;

static const ratio_point_t CO_CURVE[] = {
    {0.70f, 5.0f},
    {0.50f, 20.0f},
    {0.35f, 50.0f},
    {0.25f, 150.0f},
    {0.18f, 500.0f},
    {0.13f, 1000.0f},
    {0.10f, 5000.0f},
};
static const int CO_CURVE_LEN = sizeof(CO_CURVE) / sizeof(CO_CURVE[0]);

#define CALIBRATION_SAMPLES  20
#define CALIBRATION_DELAY_MS 50
#define CALIBRATION_MIN_VALID_SAMPLES ((CALIBRATION_SAMPLES * 3) / 4)

/**
 * @brief Log-log interpolation between two points.
 */
static float log_interp(float r1, float p1, float r2, float p2, float r)
{
    float log_r1 = logf(r1);
    float log_p1 = logf(p1);
    float log_r2 = logf(r2);
    float log_p2 = logf(p2);
    float log_r = logf(r);

    float t = (log_r - log_r1) / (log_r2 - log_r1);
    return expf(log_p1 + t * (log_p2 - log_p1));
}

/**
 * @brief Convert Rs/R0 ratio to CO ppm using lookup + interpolation.
 *
 * CO: ratio DECREASES as ppm increases (curve is monotonically decreasing).
 */
static float ratio_to_ppm_co(float ratio)
{
    /* Above clean-air baseline — no CO detected */
    if (ratio >= CO_CURVE[0].ratio) {
        return 0.0f;
    }
    /* Below minimum ratio — clamp to max range */
    if (ratio <= CO_CURVE[CO_CURVE_LEN - 1].ratio) {
        return GM702B_CO_PPM_MAX;
    }
    /* Find interval and interpolate (ratio is decreasing in table) */
    for (int i = 0; i < CO_CURVE_LEN - 1; i++) {
        if (ratio <= CO_CURVE[i].ratio && ratio >= CO_CURVE[i + 1].ratio) {
            return log_interp(CO_CURVE[i].ratio, CO_CURVE[i].ppm, CO_CURVE[i + 1].ratio, CO_CURVE[i + 1].ppm, ratio);
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

/* ── Public API ────────────────────────────────────────────────────────── */

esp_err_t gm702b_init(gm702b_t *dev, adc_channel_t channel, float rl, float vc)
{
    CHECK_ARG(dev && rl > 0 && vc > 0);

    dev->channel = channel;
    dev->rl = rl;
    dev->vc = vc;
    dev->r0 = 0.0f;
    dev->calibrated = false;

    CHECK(adc_bus_config_channel(channel, ADC_ATTEN_DB_12));

    ESP_LOGI(TAG, "CO sensor initialized on ADC1 channel %d (RL=%.0f ohm, VC=%.1fV)", (int)channel, rl, vc);
    return ESP_OK;
}

esp_err_t gm702b_calibrate(gm702b_t *dev)
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
            ESP_LOGW(TAG,
                     "Calibration sample %d/%d failed: %s",
                     i + 1,
                     CALIBRATION_SAMPLES,
                     esp_err_to_name(err));
            continue;
        }

        float vout = (float)mv / 1000.0f;
        float rs = voltage_to_rs(vout, dev->rl, dev->vc);
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

    dev->r0 = rs_sum / (float)valid;
    dev->calibrated = true;

    ESP_LOGI(TAG, "Calibration complete: R0 = %.0f ohm (%d samples)", dev->r0, valid);
    return ESP_OK;
}

esp_err_t gm702b_read(gm702b_t *dev, float *co_ppm)
{
    CHECK_ARG(dev && co_ppm);

    if (!dev->calibrated) {
        ESP_LOGW(TAG, "Sensor not calibrated — returning raw ratio as ppm estimate");
    }

    int mv;
    CHECK(adc_bus_read_voltage(dev->channel, &mv));

    float vout = (float)mv / 1000.0f;
    float rs = voltage_to_rs(vout, dev->rl, dev->vc);

    if (dev->calibrated && dev->r0 > 0) {
        float ratio = rs / dev->r0;
        *co_ppm = ratio_to_ppm_co(ratio);
    } else {
        *co_ppm = 0.0f;
    }

    return ESP_OK;
}

esp_err_t gm702b_read_ratio(gm702b_t *dev, float *ratio)
{
    CHECK_ARG(dev && ratio && dev->calibrated && dev->r0 > 0);

    int mv;
    CHECK(adc_bus_read_voltage(dev->channel, &mv));

    float vout = (float)mv / 1000.0f;
    float rs = voltage_to_rs(vout, dev->rl, dev->vc);
    *ratio = rs / dev->r0;

    return ESP_OK;
}

esp_err_t gm702b_read_voltage(gm702b_t *dev, int *voltage_mv)
{
    CHECK_ARG(dev && voltage_mv);
    return adc_bus_read_voltage(dev->channel, voltage_mv);
}
