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
#include "esp_crt_bundle.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "led.h"
#include "mqtt_client.h"
#include "ota.h"
#include "cJSON.h"

#include <stdio.h>
#include <string.h>

static const char *TAG = "mqtt";

/* ── Driver state ────────────────────────────────────────────────────────── */

static esp_mqtt_client_handle_t s_client = NULL;
static mqtt_time_sync_cb_t s_time_sync_cb = NULL;

#define MAX_CMD_HANDLERS 8
typedef struct {
    char type[32];
    mqtt_command_cb_t cb;
} cmd_handler_entry_t;
static cmd_handler_entry_t s_cmd_handlers[MAX_CMD_HANDLERS];
static int s_cmd_handler_count = 0;

/* Buffers filled once in mqtt_start() and kept alive for the MQTT client/task */
static char s_broker_uri[128];
static char s_device_id[64];
static char s_secret_key[64];
static char s_status_topic[96];   /* device/{id}/status */
static char s_cmd_topic[96];      /* device/{id}/command */
static char s_response_topic[96]; /* device/{id}/response */
static char s_shadow_topic[128];  /* device/{id}/shadow/get_response */
static char s_ota_topic[96];      /* device/{id}/ota/update */

/* ── MQTT event handler ──────────────────────────────────────────────────── */

static void mqtt_event_handler(void *arg, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_mqtt_event_handle_t ev = (esp_mqtt_event_handle_t)event_data;

    switch ((esp_mqtt_event_id_t)event_id) {
    case MQTT_EVENT_CONNECTED: {
        ESP_LOGI(TAG, "Connected to broker");
        led_set_state(LED_STATE_ONLINE);

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
        led_set_state(LED_STATE_WIFI);
        ESP_LOGW(TAG, "Disconnected — reconnecting automatically");
        break;

    case MQTT_EVENT_DATA: {
        /* FW-04: copy topic + payload before returning from handler */
        char *topic = strndup(ev->topic, (size_t)ev->topic_len);
        char *payload = strndup(ev->data, (size_t)ev->data_len);
        if (topic && payload) {
            ESP_LOGI(TAG, "RX [%s]: %s", topic, payload);

            /* Route: command → dispatch handler → ack with actual result */
            if (strstr(topic, "/command") != NULL) {
                cJSON *root = cJSON_ParseWithLength(payload, strlen(payload));
                if (root != NULL) {
                    const char *cmd_status = "done";
                    bool command_handled = false;

                    /* Dispatch command handlers */
                    cJSON *j_type = cJSON_GetObjectItemCaseSensitive(root, "type");
                    cJSON *j_ts = cJSON_GetObjectItemCaseSensitive(root, "ts");
                    if (!cJSON_IsString(j_type)) {
                        cmd_status = "error";
                        ESP_LOGW(TAG, "command message missing string type");
                    } else if (strcmp(j_type->valuestring, "set_time") == 0) {
                        command_handled = true;
                        if (cJSON_IsNumber(j_ts) && s_time_sync_cb != NULL) {
                            s_time_sync_cb((uint32_t)j_ts->valuedouble);
                            ESP_LOGI(TAG, "set_time dispatched: ts=%lu", (unsigned long)(uint32_t)j_ts->valuedouble);
                        } else {
                            cmd_status = "error";
                            ESP_LOGW(TAG, "set_time command missing ts or callback");
                        }
                    } else if (strcmp(j_type->valuestring, "set_config") == 0) {
                        command_handled = true;
                        cmd_status = "error";
                        ESP_LOGW(TAG, "set_config is not accepted over MQTT; use local POST /api/config before first login");
                    } else {
                        for (int i = 0; i < s_cmd_handler_count; i++) {
                            if (strcmp(j_type->valuestring, s_cmd_handlers[i].type) == 0) {
                                command_handled = true;
                                esp_err_t hr = s_cmd_handlers[i].cb(j_type->valuestring, payload);
                                if (hr != ESP_OK) {
                                    cmd_status = "error";
                                    ESP_LOGW(TAG,
                                             "Command '%s' handler returned %s",
                                             j_type->valuestring,
                                             esp_err_to_name(hr));
                                }
                                break;
                            }
                        }
                        if (!command_handled) {
                            cmd_status = "error";
                            ESP_LOGW(TAG, "unsupported command type: %s", j_type->valuestring);
                        }
                    }

                    /* Send ack AFTER execution with actual status */
                    cJSON *j_cmd_id = cJSON_GetObjectItemCaseSensitive(root, "command_id");
                    if (cJSON_IsString(j_cmd_id)) {
                        char response[128];
                        snprintf(response,
                                 sizeof(response),
                                 "{\"command_id\":\"%s\",\"status\":\"%s\"}",
                                 j_cmd_id->valuestring,
                                 cmd_status);
                        esp_mqtt_client_publish(s_client, s_response_topic, response, 0, 1, 0);
                        ESP_LOGI(TAG, "Command ack → %s", s_response_topic);
                    } else {
                        ESP_LOGW(TAG, "command message missing command_id");
                    }

                    cJSON_Delete(root);
                } else {
                    ESP_LOGW(TAG, "command message is not valid JSON");
                }
            }

            /* Route: OTA update trigger */
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

/* ── FreeRTOS tasks ──────────────────────────────────────────────────────── */

static void mqtt_task(void *arg)
{
    esp_mqtt_client_config_t cfg = {
        .broker =
            {
                .address.uri = s_broker_uri,
                .verification.crt_bundle_attach = esp_crt_bundle_attach,
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

void mqtt_register_time_sync_cb(mqtt_time_sync_cb_t cb)
{
    s_time_sync_cb = cb;
}

void mqtt_register_command_handler(const char *type, mqtt_command_cb_t cb)
{
    if (!type || !cb)
        return;
    if (s_cmd_handler_count >= MAX_CMD_HANDLERS) {
        ESP_LOGW(TAG, "mqtt_register_command_handler: table full (max %d)", MAX_CMD_HANDLERS);
        return;
    }
    strlcpy(s_cmd_handlers[s_cmd_handler_count].type, type, sizeof(s_cmd_handlers[s_cmd_handler_count].type));
    s_cmd_handlers[s_cmd_handler_count].cb = cb;
    s_cmd_handler_count++;
    ESP_LOGI(TAG, "Command handler registered: type=%s", type);
}

esp_err_t mqtt_start(const char *broker_uri, const char *device_id, const char *secret_key)
{
    if (device_id == NULL || device_id[0] == '\0' || secret_key == NULL || secret_key[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    strlcpy(s_broker_uri,
            (broker_uri != NULL && broker_uri[0] != '\0') ? broker_uri : CONFIG_SA_MQTT_BROKER_URI,
            sizeof(s_broker_uri));
    strlcpy(s_device_id, device_id, sizeof(s_device_id));
    strlcpy(s_secret_key, secret_key, sizeof(s_secret_key));

    /* Build topic strings from device ID */
    snprintf(s_status_topic, sizeof(s_status_topic), "device/%s/status", s_device_id);
    snprintf(s_cmd_topic, sizeof(s_cmd_topic), "device/%s/command", s_device_id);
    snprintf(s_response_topic, sizeof(s_response_topic), "device/%s/response", s_device_id);
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

esp_err_t mqtt_stop(void)
{
    if (s_client == NULL) {
        return ESP_OK;
    }
    esp_mqtt_client_stop(s_client);
    esp_mqtt_client_destroy(s_client);
    s_client = NULL;
    ESP_LOGI(TAG, "MQTT client stopped");
    return ESP_OK;
}
