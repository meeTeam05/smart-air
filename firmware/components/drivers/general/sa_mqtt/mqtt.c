/**
 * @file mqtt.c
 *
 * @brief MQTT client — TLS connection to EMQX, LWT, pub/sub.
 *
 * Architecture:
 *   - mqtt_start() creates mqtt_task (Core 1, Priority 6, 6144 B).
 *   - mqtt_task initialises esp_mqtt_client and calls start; then deletes
 *     itself — the library manages the connection lifecycle internally.
 *   - All subscriptions are (re)registered in MQTT_EVENT_CONNECTED per FW-05.
 *   - MQTT_EVENT_DATA payload is copied before the handler returns per FW-04.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "mqtt.h"

#include "config.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mqtt_client.h"
#include "ota.h"
#include "cJSON.h"

#include <stdio.h>
#include <string.h>

static const char *TAG = "mqtt";

/* ── Embedded CA certificate (server/emqx/certs/server.crt) ─────────────── */

extern const uint8_t ca_cert_pem_start[] asm("_binary_ca_cert_pem_start");
extern const uint8_t ca_cert_pem_end[] asm("_binary_ca_cert_pem_end");

/* ── Driver state ────────────────────────────────────────────────────────── */

static esp_mqtt_client_handle_t s_client = NULL;

/* Buffers filled once in mqtt_start() and kept alive for the MQTT client/task */
static char s_broker_uri[128];
static char s_device_id[64];
static char s_secret_key[64];
static char s_status_topic[96];  /* device/{id}/status */
static char s_cmd_topic[96];     /* device/{id}/command */
static char s_shadow_topic[128]; /* device/{id}/shadow/get_response */
static char s_ota_topic[96];     /* device/{id}/ota/update */

/* ── Internal helpers ────────────────────────────────────────────────────── */

/**
 * If device_id is NULL or empty, fall back to the WiFi MAC address.
 */
static void resolve_device_id(const char *input, char *out, size_t out_len)
{
    if (input != NULL && input[0] != '\0') {
        snprintf(out, out_len, "%s", input);
    } else {
        uint8_t mac[6];
        esp_read_mac(mac, ESP_MAC_WIFI_STA);
        snprintf(out, out_len, "%02x:%02x:%02x:%02x:%02x:%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
        ESP_LOGW(TAG, "device_id empty — using MAC: %s", out);
    }
}

/* ── MQTT event handler ──────────────────────────────────────────────────── */

static void mqtt_event_handler(void *arg, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t ev = (esp_mqtt_event_handle_t)event_data;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED: {
        ESP_LOGI(TAG, "Connected to broker");

        /* Publish retained online status */
        char msg[80];
        snprintf(msg, sizeof(msg), "{\"online\":true,\"firmware\":\"%s\"}", CONFIG_FIRMWARE_VERSION);
        esp_mqtt_client_publish(s_client, s_status_topic, msg, 0, 1, 1);
        ESP_LOGI(TAG, "Published online status → %s", s_status_topic);

        /* FW-05: subscribe inside CONNECTED so re-connects re-subscribe */
        esp_mqtt_client_subscribe(s_client, s_cmd_topic, 1);
        esp_mqtt_client_subscribe(s_client, s_shadow_topic, 1);
        esp_mqtt_client_subscribe(s_client, s_ota_topic, 1);
        ESP_LOGI(TAG, "Subscribed to command / shadow / ota topics");
        break;
    }

    case MQTT_EVENT_DISCONNECTED:
        ESP_LOGW(TAG, "Disconnected — reconnecting automatically");
        break;

    case MQTT_EVENT_DATA: {
        /* FW-04: copy topic + payload before returning from handler */
        char *topic = strndup(ev->topic, (size_t)ev->topic_len);
        char *payload = strndup(ev->data, (size_t)ev->data_len);
        if (topic && payload) {
            ESP_LOGI(TAG, "RX [%s]: %s", topic, payload);

            /* Route OTA update trigger */
            if (strstr(topic, "/ota/update") != NULL) {
                cJSON *root = cJSON_ParseWithLength(payload, strlen(payload));
                if (root != NULL) {
                    cJSON *j_url = cJSON_GetObjectItemCaseSensitive(root, "url");
                    cJSON *j_sha = cJSON_GetObjectItemCaseSensitive(root, "sha256");
                    if (cJSON_IsString(j_url) && cJSON_IsString(j_sha)) {
                        ota_trigger(j_url->valuestring, j_sha->valuestring);
                    } else {
                        ESP_LOGW(TAG, "OTA update message missing url or sha256");
                    }
                    cJSON_Delete(root);
                } else {
                    ESP_LOGW(TAG, "OTA update message is not valid JSON");
                }
            }
        }
        free(topic);
        free(payload);
        break;
    }

    case MQTT_EVENT_ERROR:
        if (ev->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
            ESP_LOGE(TAG,
                     "TLS error — esp_tls_last_error=0x%x tls_stack_err=0x%x",
                     ev->error_handle->esp_tls_last_esp_err,
                     ev->error_handle->esp_tls_stack_err);
        }
        break;

    case MQTT_EVENT_SUBSCRIBED:
        ESP_LOGI(TAG, "Subscribed (msg_id=%d)", ev->msg_id);
        break;

    default:
        break;
    }
}

/* ── FreeRTOS task ───────────────────────────────────────────────────────── */

static void mqtt_task(void *arg)
{
    esp_mqtt_client_config_t cfg = {
        .broker =
            {
                .address.uri = s_broker_uri,
                .verification.certificate = (const char *)ca_cert_pem_start,
            },
        .credentials =
            {
                .username = s_device_id,
                .authentication.password = s_secret_key,
                .client_id = s_device_id,
            },
        .session =
            {
                .last_will =
                    {
                        .topic = s_status_topic,
                        .msg = "{\"online\":false}",
                        .qos = 1,
                        .retain = 1,
                    },
                .keepalive = 60,
            },
        .network =
            {
                .reconnect_timeout_ms = 5000,
            },
    };

    s_client = esp_mqtt_client_init(&cfg);
    if (s_client == NULL) {
        ESP_LOGE(TAG, "esp_mqtt_client_init failed");
        vTaskDelete(NULL);
        return;
    }

    esp_mqtt_client_register_event(s_client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(s_client);

    /* Task work is done — library runs the connection loop internally */
    vTaskDelete(NULL);
}

/* ── Public API ──────────────────────────────────────────────────────────── */

esp_err_t mqtt_start(const char *broker_uri, const char *device_id, const char *secret_key)
{
    strlcpy(s_broker_uri, (broker_uri != NULL && broker_uri[0] != '\0') ? broker_uri : CONFIG_SA_MQTT_BROKER_URI,
            sizeof(s_broker_uri));
    resolve_device_id(device_id, s_device_id, sizeof(s_device_id));
    strlcpy(s_secret_key, secret_key != NULL ? secret_key : "", sizeof(s_secret_key));

    /* Build topic strings from device ID */
    snprintf(s_status_topic, sizeof(s_status_topic), "device/%s/status", s_device_id);
    snprintf(s_cmd_topic, sizeof(s_cmd_topic), "device/%s/command", s_device_id);
    snprintf(s_shadow_topic, sizeof(s_shadow_topic), "device/%s/shadow/get_response", s_device_id);
    snprintf(s_ota_topic, sizeof(s_ota_topic), "device/%s/ota/update", s_device_id);

    ESP_LOGI(TAG, "Starting MQTT client (id=%s, broker=%s)", s_device_id, s_broker_uri);

    /* Per task map: Core 1, Priority 6, 6144 B */
    BaseType_t rc = xTaskCreatePinnedToCore(mqtt_task, "mqtt_task", 6144, NULL, 6, NULL, APP_CPU_NUM);
    if (rc != pdPASS) {
        ESP_LOGE(TAG, "xTaskCreatePinnedToCore failed");
        return ESP_FAIL;
    }
    return ESP_OK;
}

int mqtt_publish(const char *topic, const char *payload, int qos, bool retain)
{
    if (s_client == NULL) {
        return -1;
    }
    return esp_mqtt_client_publish(s_client, topic, payload, 0, qos, retain ? 1 : 0);
}
