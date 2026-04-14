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

/**
 * @brief Start the MQTT client and connect to the broker asynchronously.
 *
 * Spawns mqtt_task (Core 1, Priority 6, 6144 B stack).
 * Returns immediately after the task is created — the actual TCP/TLS
 * connection happens in the background.
 *
 * @param broker_uri  Full broker URI, e.g. "mqtts://192.168.1.16:8883"
 * @param device_id   MQTT client ID / username. Pass NULL or "" to use
 *                    the WiFi MAC address as a fallback.
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
