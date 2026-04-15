/**
 * @file sensor_task.c
 *
 * @brief Sensor polling task — reads SHT3x + DS3231 and publishes telemetry.
 *
 * Architecture:
 *   - sensor_task_start() spawns sensor_task_fn (Core 1, Priority 5, 4096 B).
 *   - On first iteration the device_id is resolved once via config_get_mqtt_creds()
 *     and the telemetry topic is built.
 *   - Every 5 s: measure SHT3x → get DS3231 timestamp → publish JSON to MQTT.
 *   - Sensor read failures are logged as warnings; the loop continues.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "sensor_task.h"

#include "config.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mqtt.h"

#include <stdio.h>
#include <string.h>

static const char *TAG = "sensor_task";

#define SENSOR_POLL_MS 5000

/* ── Internal helper ──────────────────────────────────────────────────── */

/**
 * Resolve device_id: use config value if set, fall back to WiFi MAC address.
 * Mirrors the logic in mqtt.c resolve_device_id().
 */
static void resolve_device_id(const char *config_id, char *out, size_t out_len)
{
    if (config_id != NULL && config_id[0] != '\0') {
        snprintf(out, out_len, "%s", config_id);
    } else {
        uint8_t mac[6];
        esp_read_mac(mac, ESP_MAC_WIFI_STA);
        snprintf(out, out_len, "%02x:%02x:%02x:%02x:%02x:%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    }
}

/* ── Task context passed via xTaskCreate arg ─────────────────────────────── */

typedef struct {
    sht3x_t *sht3x;
    ds3231_t *ds3231;
} sensor_task_arg_t;

/* ── FreeRTOS task ───────────────────────────────────────────────────────── */

static void sensor_task_fn(void *arg)
{
    sensor_task_arg_t *ctx = (sensor_task_arg_t *)arg;

    /* Resolve device_id once to build the telemetry topic */
    char device_id[64] = {0};
    char telemetry_topic[96] = {0};
    char shadow_topic[96] = {0};
    {
        char broker_uri[128] = {0};
        char config_device_id[64] = {0};
        char secret_key[64] = {0};
        esp_err_t err = config_get_mqtt_creds(broker_uri, sizeof(broker_uri),
                                              config_device_id, sizeof(config_device_id),
                                              secret_key, sizeof(secret_key));
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "Failed to read config (%s) — task exiting", esp_err_to_name(err));
            vTaskDelete(NULL);
            return;
        }
        resolve_device_id(config_device_id, device_id, sizeof(device_id));
        snprintf(telemetry_topic, sizeof(telemetry_topic), "device/%s/telemetry",     device_id);
        snprintf(shadow_topic,    sizeof(shadow_topic),    "device/%s/shadow/report", device_id);
        ESP_LOGI(TAG, "Telemetry topic: %s", telemetry_topic);
    }

    while (1) {
        float temperature = 0.0f;
        float humidity = 0.0f;
        uint32_t timestamp = 0;

        /* Read SHT3x */
        esp_err_t sht_err = sht3x_measure(ctx->sht3x, &temperature, &humidity);
        if (sht_err != ESP_OK) {
            ESP_LOGW(TAG, "SHT3x read failed (%s)", esp_err_to_name(sht_err));
        }

        /* Read DS3231 Unix timestamp */
        esp_err_t rtc_err = ds3231_get_timestamp(ctx->ds3231, &timestamp);
        if (rtc_err != ESP_OK) {
            ESP_LOGW(TAG, "DS3231 read failed (%s)", esp_err_to_name(rtc_err));
        }

        /* Only publish if both reads succeeded */
        if (sht_err == ESP_OK && rtc_err == ESP_OK) {
            char payload[128];
            snprintf(payload, sizeof(payload),
                     "{\"device_id\":\"%s\",\"ts\":%lu,\"temperature\":%.1f,\"humidity\":%.1f}",
                     device_id, (unsigned long)timestamp, temperature, humidity);

            int msg_id = mqtt_publish(telemetry_topic, payload, 1, false);
            if (msg_id >= 0) {
                ESP_LOGI(TAG, "Telemetry published (msg_id=%d): %s", msg_id, payload);
            } else {
                ESP_LOGW(TAG, "mqtt_publish failed — MQTT not ready yet");
            }

            /* Shadow report — current sensor state + device timestamp */
            char shadow[96];
            snprintf(shadow, sizeof(shadow),
                     "{\"temperature\":%.1f,\"humidity\":%.1f,\"ts\":%lu}",
                     temperature, humidity, (unsigned long)timestamp);
            mqtt_publish(shadow_topic, shadow, 1, false);
        }

        vTaskDelay(pdMS_TO_TICKS(SENSOR_POLL_MS));
    }
}

/* ── Public API ──────────────────────────────────────────────────────────── */

esp_err_t sensor_task_start(sht3x_t *sht3x, ds3231_t *ds3231)
{
    static sensor_task_arg_t ctx;
    ctx.sht3x = sht3x;
    ctx.ds3231 = ds3231;

    /* Per firmware task map: Core 1, Priority 5, 4096 B */
    BaseType_t rc = xTaskCreatePinnedToCore(sensor_task_fn, "sensor_task", 4096, &ctx, 5, NULL, APP_CPU_NUM);
    if (rc != pdPASS) {
        ESP_LOGE(TAG, "xTaskCreatePinnedToCore failed");
        return ESP_FAIL;
    }
    ESP_LOGI(TAG, "sensor_task started");
    return ESP_OK;
}
