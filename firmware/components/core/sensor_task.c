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
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mqtt.h"

#include <string.h>
#include <time.h>

static const char *TAG = "sensor_task";

/* ── Task context passed via xTaskCreate arg ─────────────────────────────── */

typedef struct {
    sht3x_t  *sht3x;
    ds3231_t *ds3231;
    gm702b_t *co;
    gm102b_t *no2;
    char device_id[64];
} sensor_task_arg_t;

/* ── FreeRTOS task ───────────────────────────────────────────────────────── */

static void sensor_task_fn(void *arg)
{
    sensor_task_arg_t *ctx = (sensor_task_arg_t *)arg;

    /* Build topic strings from the device_id passed via task arg */
    char telemetry_topic[96] = {0};
    char shadow_topic[96] = {0};
    snprintf(telemetry_topic, sizeof(telemetry_topic), "device/%s/telemetry", ctx->device_id);
    snprintf(shadow_topic, sizeof(shadow_topic), "device/%s/shadow/report", ctx->device_id);
    ESP_LOGI(TAG, "Telemetry topic: %s", telemetry_topic);

    while (1) {
        float temperature = 0.0f;
        float humidity = 0.0f;
        float co_ppm = 0.0f;
        float no2_ppm = 0.0f;
        uint32_t timestamp = 0;
        bool have_sht = false;
        bool have_rtc = false;
        bool have_co  = false;
        bool have_no2 = false;

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

        /* Telemetry — always publish; null for unavailable sensor fields */
        cJSON *root = cJSON_CreateObject();
        if (root != NULL) {
            cJSON_AddStringToObject(root, "device_id", ctx->device_id);
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
                int msg_id = mqtt_publish(telemetry_topic, payload, 1, false);
                if (msg_id >= 0) {
                    ESP_LOGI(TAG, "Telemetry published (msg_id=%d): %s", msg_id, payload);
                } else {
                    ESP_LOGW(TAG, "mqtt_publish failed — MQTT not ready yet");
                }
                cJSON_free(payload);
            }
            cJSON_Delete(root);
        }

        /* Shadow report — same shape as telemetry minus device_id */
        cJSON *shadow = cJSON_CreateObject();
        if (shadow != NULL) {
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
                int shadow_id = mqtt_publish(shadow_topic, shadow_str, 1, false);
                if (shadow_id < 0) {
                    ESP_LOGW(TAG, "shadow mqtt_publish failed — MQTT not ready yet");
                }
                cJSON_free(shadow_str);
            }
            cJSON_Delete(shadow);
        }

        vTaskDelay(pdMS_TO_TICKS(SA_SENSOR_POLLING_INTERVAL));
    }
}

/* ── Public API ──────────────────────────────────────────────────────────── */

esp_err_t sensor_task_start(sht3x_t *sht3x, ds3231_t *ds3231,
                            gm702b_t *co, gm102b_t *no2,
                            const char *device_id)
{
    static sensor_task_arg_t ctx;
    ctx.sht3x  = sht3x;
    ctx.ds3231 = ds3231;
    ctx.co     = co;
    ctx.no2    = no2;
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
