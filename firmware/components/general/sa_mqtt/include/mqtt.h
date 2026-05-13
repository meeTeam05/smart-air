/**
 * @file mqtt.h
 *
 * @brief MQTT client — TLS connection to EMQX, LWT, pub/sub API.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#pragma once

#include "esp_err.h"
#include <stdbool.h>
#include <stdint.h>

/**
 * @brief Callback invoked when a set_time command is received from the app.
 *        The implementation should write the timestamp to the DS3231 RTC.
 *
 * @param ts Unix timestamp in seconds (from phone).
 */
typedef void (*mqtt_time_sync_cb_t)(uint32_t ts);

/**
 * @brief Register a callback to be called when a set_time command arrives.
 *        Call once from sysload_init() after DS3231 is initialised.
 *
 * @param cb Callback function pointer. Pass NULL to deregister.
 */
void mqtt_register_time_sync_cb(mqtt_time_sync_cb_t cb);

/**
 * @brief Callback invoked when a command of a registered type arrives.
 *
 * @param type         The "type" field value from the command JSON.
 * @param json_payload Full command JSON string (FW-04: already copied, valid for call duration).
 * @return ESP_OK on success → MQTT ack reports "done". Any other value → ack reports "error".
 */
typedef esp_err_t (*mqtt_command_cb_t)(const char *type, const char *json_payload);

/**
 * @brief Register a handler for a specific command type.
 *
 * Up to 8 handlers may be registered. Call from sysload_init() before mqtt_start().
 * The handler is invoked synchronously inside the MQTT event callback — keep it short
 * (write to queue or set a flag; do not block).
 *
 * @param type  Command type string to match against the "type" JSON field.
 * @param cb    Handler function.
 */
void mqtt_register_command_handler(const char *type, mqtt_command_cb_t cb);

/**
 * @brief Start the MQTT client and connect to the broker asynchronously.
 *
 * Spawns mqtt_task (Core 1, Priority 6, 6144 B stack).
 * Returns immediately after the task is created — the actual TCP/TLS
 * connection happens in the background.
 *
 * @param broker_uri  Full broker URI, e.g. "mqtts://mqtt.minhnhat05.xyz:8883"
 * @param device_id   MQTT client ID / username. Must be the lowercase
 *                    Wi-Fi STA MAC resolved by config_get_device_id().
 * @param secret_key  Per-device MQTT password (stored in NVS / Kconfig).
 *
 * @return ESP_OK on success, ESP_FAIL if task creation fails.
 */
esp_err_t mqtt_start(const char *broker_uri,
                     const char *device_id,
                     const char *secret_key);

/**
 * @brief Publish a message to any topic. Thread-safe.
 *
 * Can be called from sensor_task, command handlers, or any other task
 * after mqtt_start() returns.
 *
 * @param topic    Full topic string.
 * @param payload  Null-terminated JSON (or any string) payload.
 * @param qos      MQTT QoS level: 0, 1, or 2.
 * @param retain   true to set the MQTT retain flag.
 *
 * @return Message ID (>= 0) on success, -1 if client not ready.
 */
int mqtt_publish(const char *topic, const char *payload, int qos, bool retain);

/**
 * @brief Stop and destroy the MQTT client.
 *
 * Publishes the offline LWT is handled automatically by the broker on disconnect.
 * Call before factory reset or any clean-shutdown sequence that precedes esp_restart().
 *
 * Safe to call if mqtt_start() was never called (no-op when client is NULL).
 *
 * @return ESP_OK always.
 */
esp_err_t mqtt_stop(void);
