/**
 * @file ota.c
 *
 * @brief HTTPS OTA firmware update.
 *
 * Architecture:
 *   - ota_task_start() creates a queue (depth=1) and spawns ota_task_fn.
 *   - ota_trigger() validates the URL and sends {url, sha256} to the queue.
 *   - ota_task_fn blocks on the queue, downloads the firmware via esp_https_ota,
 *     publishes progress every 10% to device/{id}/ota/progress, then reboots.
 *   - ota_validate_and_commit() marks the new firmware valid after the system
 *     proves it works — satisfies SEC-03 rollback requirement.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "ota.h"

#include "esp_https_ota.h"
#include "esp_log.h"
#include "esp_ota_ops.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/task.h"

#include <stdbool.h>
#include <string.h>

/* Forward declaration — resolved at link time from sa_mqtt component (no CMake dep needed) */
extern int mqtt_publish(const char *topic, const char *payload, int qos, bool retain);

static const char *TAG = "ota";

/* ── Embedded CA certificate ─────────────────────────────────────────────── */

extern const uint8_t ca_cert_pem_start[] asm("_binary_ca_cert_pem_start");
extern const uint8_t ca_cert_pem_end[] asm("_binary_ca_cert_pem_end");

/* ── Driver state ────────────────────────────────────────────────────────── */

typedef struct {
    char url[256];
    char sha256[65];
} ota_msg_t;

static QueueHandle_t s_ota_queue = NULL;
static char s_progress_topic[96]; /* device/{id}/ota/progress */

/* ── Internal helpers ────────────────────────────────────────────────────── */

static void publish_progress(int pct, const char *status)
{
    char msg[80];
    if (status != NULL) {
        snprintf(msg, sizeof(msg), "{\"progress\":%d,\"status\":\"%s\"}", pct, status);
    } else {
        snprintf(msg, sizeof(msg), "{\"progress\":%d}", pct);
    }
    mqtt_publish(s_progress_topic, msg, 1, false);
}

/* ── FreeRTOS task ───────────────────────────────────────────────────────── */

static void ota_task_fn(void *arg)
{
    ota_msg_t msg;

    while (1) {
        /* Block until a trigger arrives */
        xQueueReceive(s_ota_queue, &msg, portMAX_DELAY);

        ESP_LOGI(TAG, "OTA triggered: %s", msg.url);
        publish_progress(0, "starting");

        /* Configure HTTPS OTA */
        esp_http_client_config_t http_cfg = {
            .url = msg.url,
            .cert_pem = (const char *)ca_cert_pem_start,
            .keep_alive_enable = true,
        };
        esp_https_ota_config_t ota_cfg = {
            .http_config = &http_cfg,
        };

        esp_https_ota_handle_t ota_handle = NULL;
        esp_err_t err = esp_https_ota_begin(&ota_cfg, &ota_handle);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "esp_https_ota_begin failed (%s)", esp_err_to_name(err));
            publish_progress(0, "failed");
            continue;
        }

        /* Download loop — publish progress every 10% */
        int last_bucket = -1;
        while (1) {
            err = esp_https_ota_perform(ota_handle);
            if (err != ESP_ERR_HTTPS_OTA_IN_PROGRESS) {
                break;
            }

            int read = esp_https_ota_get_image_len_read(ota_handle);
            int total = esp_https_ota_get_image_size(ota_handle);
            if (total > 0) {
                int pct = (read * 100) / total;
                int bucket = (pct / 10) * 10;
                if (bucket != last_bucket) {
                    publish_progress(bucket, NULL);
                    last_bucket = bucket;
                }
            }
        }

        if (err != ESP_OK) {
            ESP_LOGE(TAG, "esp_https_ota_perform failed (%s)", esp_err_to_name(err));
            esp_https_ota_abort(ota_handle);
            publish_progress(0, "failed");
            continue;
        }

        err = esp_https_ota_finish(ota_handle);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "esp_https_ota_finish failed (%s)", esp_err_to_name(err));
            publish_progress(0, "failed");
            continue;
        }

        ESP_LOGI(TAG, "OTA download complete — rebooting");
        publish_progress(100, "rebooting");

        /* Small delay to let the MQTT message flush */
        vTaskDelay(pdMS_TO_TICKS(500));
        esp_restart();
    }
}

/* ── Public API ──────────────────────────────────────────────────────────── */

esp_err_t ota_task_start(const char *device_id)
{
    snprintf(s_progress_topic, sizeof(s_progress_topic),
             "device/%s/ota/progress", device_id != NULL ? device_id : "");

    s_ota_queue = xQueueCreate(1, sizeof(ota_msg_t));
    if (s_ota_queue == NULL) {
        ESP_LOGE(TAG, "xQueueCreate failed");
        return ESP_FAIL;
    }

    /* Per firmware task map: Core 1, Priority 3, 8192 B */
    BaseType_t rc = xTaskCreatePinnedToCore(ota_task_fn, "ota_task", 8192, NULL, 3, NULL, APP_CPU_NUM);
    if (rc != pdPASS) {
        ESP_LOGE(TAG, "xTaskCreatePinnedToCore failed");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "ota_task started (topic: %s)", s_progress_topic);
    return ESP_OK;
}

esp_err_t ota_trigger(const char *url, const char *sha256)
{
    /* SEC-02: HTTPS only */
    if (url == NULL || strncmp(url, "https://", 8) != 0) {
        ESP_LOGW(TAG, "OTA trigger rejected — URL must start with https://");
        return ESP_ERR_INVALID_ARG;
    }

    if (s_ota_queue == NULL) {
        ESP_LOGW(TAG, "OTA trigger ignored — queue not initialised");
        return ESP_FAIL;
    }

    ota_msg_t msg = {0};
    strlcpy(msg.url, url, sizeof(msg.url));
    if (sha256 != NULL) {
        strlcpy(msg.sha256, sha256, sizeof(msg.sha256));
    }

    /* Non-blocking: drop trigger if a download is already queued */
    if (xQueueSend(s_ota_queue, &msg, 0) != pdTRUE) {
        ESP_LOGW(TAG, "OTA trigger dropped — queue full (download already pending)");
    } else {
        ESP_LOGI(TAG, "OTA queued: %s", url);
    }
    return ESP_OK;
}

void ota_validate_and_commit(void)
{
    const esp_partition_t *running = esp_ota_get_running_partition();
    esp_ota_img_states_t state;

    if (esp_ota_get_state_partition(running, &state) == ESP_OK
        && state == ESP_OTA_IMG_PENDING_VERIFY) {
        esp_err_t err = esp_ota_mark_app_valid_cancel_rollback();
        if (err == ESP_OK) {
            ESP_LOGI(TAG, "OTA validated — new firmware committed");
        } else {
            ESP_LOGE(TAG, "esp_ota_mark_app_valid_cancel_rollback failed (%s)", esp_err_to_name(err));
        }
    }
}
