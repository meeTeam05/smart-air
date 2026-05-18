/**
 * @file sensor_task.c
 *
 * @brief Sensor polling task — SHT3x + DS3231 + GM-702B CO + GM-102B NO2.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "sensor_task.h"

#include "cJSON.h"
#include "esp_log.h"
#include "esp_system.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mqtt.h"

#include <string.h>
#include <time.h>

static const char *TAG = "sensor_task";

#define PENDING_PAYLOAD_MAX 256

static portMUX_TYPE s_enabled_lock = portMUX_INITIALIZER_UNLOCKED;
static bool s_enabled = true;
static uint32_t s_telemetry_json_failures = 0;
static uint32_t s_shadow_json_failures = 0;
static uint32_t s_telemetry_publish_failures = 0;
static uint32_t s_shadow_publish_failures = 0;

typedef struct {
    bool has_payload;
    char payload[PENDING_PAYLOAD_MAX];
} pending_payload_t;

static pending_payload_t s_pending_telemetry = {0};
static pending_payload_t s_pending_shadow = {0};

static void log_json_failure(const char *stream, const char *stage, uint32_t *counter)
{
    (*counter)++;
    ESP_LOGE(TAG,
             "%s JSON %s failed (count=%lu free_heap=%lu min_free_heap=%lu)",
             stream,
             stage,
             (unsigned long)*counter,
             (unsigned long)esp_get_free_heap_size(),
             (unsigned long)esp_get_minimum_free_heap_size());
}

static void store_pending_payload(const char *stream, pending_payload_t *pending, const char *payload)
{
    if (payload == NULL) {
        return;
    }

    size_t copied = strlcpy(pending->payload, payload, sizeof(pending->payload));
    if (copied >= sizeof(pending->payload)) {
        pending->has_payload = false;
        ESP_LOGE(TAG, "%s retry payload too large (%u bytes)", stream, (unsigned)(copied + 1U));
        return;
    }

    pending->has_payload = true;
    ESP_LOGW(TAG, "%s payload queued for retry", stream);
}

static bool publish_payload_now(const char *stream, const char *topic, const char *payload, uint32_t *counter)
{
    int msg_id = mqtt_publish(topic, payload, 1, false);
    if (msg_id < 0) {
        (*counter)++;
        ESP_LOGW(TAG,
                 "%s mqtt_publish failed (count=%lu) — MQTT not ready yet",
                 stream,
                 (unsigned long)*counter);
        return false;
    }

    ESP_LOGI(TAG, "%s published (msg_id=%d): %s", stream, msg_id, payload);
    return true;
}

static void flush_pending_payload(const char *stream, const char *topic, pending_payload_t *pending, uint32_t *counter)
{
    if (!pending->has_payload) {
        return;
    }

    if (publish_payload_now(stream, topic, pending->payload, counter)) {
        pending->has_payload = false;
        pending->payload[0] = '\0';
        ESP_LOGI(TAG, "%s retry flush succeeded", stream);
    }
}

#if SA_DEMO_NO_PERIPHERALS
typedef struct {
    float temperature;
    float humidity;
    float co_ppm;
    float no2_ppm;
} demo_sample_t;

static const demo_sample_t s_demo_samples[] = {
    {25.8f, 61.0f, 3.5f, 0.03f},
    {26.1f, 60.2f, 4.0f, 0.04f},
    {26.6f, 58.8f, 5.2f, 0.05f},
    {27.0f, 57.5f, 7.8f, 0.07f},
    {27.4f, 56.9f, 10.5f, 0.10f},
    {27.9f, 55.8f, 13.2f, 0.12f},
    {28.2f, 55.0f, 11.0f, 0.09f},
    {27.8f, 56.2f, 8.4f, 0.07f},
    {27.2f, 57.6f, 6.1f, 0.05f},
    {26.8f, 58.4f, 4.8f, 0.04f},
    {26.3f, 59.5f, 3.9f, 0.03f},
    {25.9f, 60.6f, 3.4f, 0.03f},
};

static void load_demo_sample(size_t sample_idx, float *temperature, float *humidity, float *co_ppm, float *no2_ppm)
{
    const demo_sample_t *sample = &s_demo_samples[sample_idx % (sizeof(s_demo_samples) / sizeof(s_demo_samples[0]))];
    *temperature = sample->temperature;
    *humidity = sample->humidity;
    *co_ppm = sample->co_ppm;
    *no2_ppm = sample->no2_ppm;
}
#endif

/* Task context passed via xTaskCreate arg */

typedef struct {
    sht3x_t *sht3x;
    ds3231_t *ds3231;
    gm702b_t *co;
    gm102b_t *no2;
    char device_id[64];
} sensor_task_arg_t;

/* FreeRTOS task */

static void sensor_task_fn(void *arg)
{
    sensor_task_arg_t *ctx = (sensor_task_arg_t *)arg;

    /* Build topic strings from the device_id passed via task arg */
    char telemetry_topic[96] = {0};
    char shadow_topic[96] = {0};
    snprintf(telemetry_topic, sizeof(telemetry_topic), "device/%s/telemetry", ctx->device_id);
    snprintf(shadow_topic, sizeof(shadow_topic), "device/%s/shadow/report", ctx->device_id);
    ESP_LOGI(TAG, "Telemetry topic: %s", telemetry_topic);
#if SA_DEMO_NO_PERIPHERALS
    size_t demo_sample_idx = 0;
#endif

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(SA_SENSOR_POLLING_INTERVAL));

        if (!sensor_task_get_enabled()) {
            continue;
        }

        flush_pending_payload("telemetry", telemetry_topic, &s_pending_telemetry, &s_telemetry_publish_failures);
        flush_pending_payload("shadow", shadow_topic, &s_pending_shadow, &s_shadow_publish_failures);

        float temperature = 0.0f;
        float humidity = 0.0f;
        float co_ppm = 0.0f;
        float no2_ppm = 0.0f;
        uint32_t timestamp = 0;

        bool have_sht = false;
        bool have_co = false;
        bool have_no2 = false;

#if SA_DEMO_NO_PERIPHERALS
        load_demo_sample(demo_sample_idx, &temperature, &humidity, &co_ppm, &no2_ppm);
        demo_sample_idx++;
        timestamp = (uint32_t)time(NULL);
        have_sht = true;
        have_co = true;
        have_no2 = true;
#else
        bool have_rtc = false;

        /* Read SHT3x if available */
        if (ctx->sht3x != NULL) {
            if (sht3x_measure(ctx->sht3x, &temperature, &humidity) == ESP_OK) {
                have_sht = true;
            } else {
                ESP_LOGW(TAG, "SHT3x read failed");
            }
        }

        /* Read DS3231 Unix timestamp if available */
        if (ctx->ds3231 != NULL) {
            if (ds3231_get_timestamp(ctx->ds3231, &timestamp) == ESP_OK) {
                have_rtc = true;
            } else {
                ESP_LOGW(TAG, "DS3231 read failed");
            }
        }

        /* Read CO sensor if available */
        if (ctx->co != NULL) {
            if (gm702b_read(ctx->co, &co_ppm) == ESP_OK) {
                have_co = true;
            } else {
                ESP_LOGW(TAG, "GM702B CO read failed");
            }
        }

        /* Read NO2 sensor if available */
        if (ctx->no2 != NULL) {
            if (gm102b_read(ctx->no2, &no2_ppm) == ESP_OK) {
                have_no2 = true;
            } else {
                ESP_LOGW(TAG, "GM102B NO2 read failed");
            }
        }

        /* Timestamp fallback: system time (from SNTP after WiFi connect, or epoch 0) */
        if (!have_rtc) {
            timestamp = (uint32_t)time(NULL);
        }
#endif

        /* Telemetry — always publish; null for unavailable sensor fields */
        cJSON *root = cJSON_CreateObject();
        if (root != NULL) {
            cJSON_AddStringToObject(root, "device_id", ctx->device_id);
            cJSON_AddStringToObject(root, "mode", "on");
            cJSON_AddNumberToObject(root, "ts", (double)timestamp);
            if (have_sht) {
                cJSON_AddNumberToObject(root, "temperature", (double)temperature);
                cJSON_AddNumberToObject(root, "humidity", (double)humidity);
            } else {
                cJSON_AddNullToObject(root, "temperature");
                cJSON_AddNullToObject(root, "humidity");
            }
            if (have_co) {
                cJSON_AddNumberToObject(root, "co_ppm", (double)co_ppm);
            } else {
                cJSON_AddNullToObject(root, "co_ppm");
            }
            if (have_no2) {
                cJSON_AddNumberToObject(root, "no2_ppm", (double)no2_ppm);
            } else {
                cJSON_AddNullToObject(root, "no2_ppm");
            }
            char *payload = cJSON_PrintUnformatted(root);
            if (payload != NULL) {
                if (!publish_payload_now("telemetry", telemetry_topic, payload, &s_telemetry_publish_failures)) {
                    store_pending_payload("telemetry", &s_pending_telemetry, payload);
                }
                cJSON_free(payload);
            } else {
                log_json_failure("telemetry", "serialization", &s_telemetry_json_failures);
            }
            cJSON_Delete(root);
        } else {
            log_json_failure("telemetry", "allocation", &s_telemetry_json_failures);
        }

        /* Shadow report — same shape as telemetry minus device_id */
        cJSON *shadow = cJSON_CreateObject();
        if (shadow != NULL) {
            cJSON_AddStringToObject(shadow, "mode", "on");
            if (have_sht) {
                cJSON_AddNumberToObject(shadow, "temperature", (double)temperature);
                cJSON_AddNumberToObject(shadow, "humidity", (double)humidity);
            } else {
                cJSON_AddNullToObject(shadow, "temperature");
                cJSON_AddNullToObject(shadow, "humidity");
            }
            if (have_co) {
                cJSON_AddNumberToObject(shadow, "co_ppm", (double)co_ppm);
            } else {
                cJSON_AddNullToObject(shadow, "co_ppm");
            }
            if (have_no2) {
                cJSON_AddNumberToObject(shadow, "no2_ppm", (double)no2_ppm);
            } else {
                cJSON_AddNullToObject(shadow, "no2_ppm");
            }
            cJSON_AddNumberToObject(shadow, "ts", (double)timestamp);
            char *shadow_str = cJSON_PrintUnformatted(shadow);
            if (shadow_str != NULL) {
                if (!publish_payload_now("shadow", shadow_topic, shadow_str, &s_shadow_publish_failures)) {
                    store_pending_payload("shadow", &s_pending_shadow, shadow_str);
                }
                cJSON_free(shadow_str);
            } else {
                log_json_failure("shadow", "serialization", &s_shadow_json_failures);
            }
            cJSON_Delete(shadow);
        } else {
            log_json_failure("shadow", "allocation", &s_shadow_json_failures);
        }
    }
}

/* Public API */

void sensor_task_set_enabled(bool enabled)
{
    bool changed = false;

    taskENTER_CRITICAL(&s_enabled_lock);
    if (s_enabled != enabled) {
        s_enabled = enabled;
        changed = true;
    }
    taskEXIT_CRITICAL(&s_enabled_lock);

    if (changed) {
        ESP_LOGI(TAG, "sensor task mode set to %s", enabled ? "on" : "off");
    }
}

bool sensor_task_get_enabled(void)
{
    bool enabled;

    taskENTER_CRITICAL(&s_enabled_lock);
    enabled = s_enabled;
    taskEXIT_CRITICAL(&s_enabled_lock);

    return enabled;
}

esp_err_t sensor_task_start(sht3x_t *sht3x, ds3231_t *ds3231, gm702b_t *co, gm102b_t *no2, const char *device_id)
{
    if (device_id == NULL || device_id[0] == '\0') {
        ESP_LOGE(TAG, "sensor_task_start requires non-empty device_id");
        return ESP_ERR_INVALID_ARG;
    }

    static sensor_task_arg_t ctx;
    ctx.sht3x = sht3x;
    ctx.ds3231 = ds3231;
    ctx.co = co;
    ctx.no2 = no2;
    strlcpy(ctx.device_id, device_id, sizeof(ctx.device_id));

    /* Per firmware task map: Core 1, Priority 5, 4096 B */
    BaseType_t rc = xTaskCreatePinnedToCore(sensor_task_fn, "sensor_task", 4096, &ctx, 5, NULL, APP_CPU_NUM);
    if (rc != pdPASS) {
        ESP_LOGE(TAG, "xTaskCreatePinnedToCore failed");
        return ESP_FAIL;
    }
    ESP_LOGI(TAG, "sensor_task started");
    return ESP_OK;
}
