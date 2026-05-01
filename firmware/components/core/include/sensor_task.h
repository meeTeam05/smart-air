/**
 * @file sensor_task.h
 *
 * @brief Sensor polling task — reads SHT3x + DS3231 and publishes telemetry via MQTT.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#pragma once

#include "ds3231.h"
#include "esp_err.h"
#include "sht3x.h"

/**
 * @brief Spawn sensor_task (Core 1, Priority 5, 4096 B stack).
 *
 * Polls SHT3x temperature/humidity and DS3231 Unix timestamp every 5 s,
 * then publishes to device/{id}/telemetry via mqtt_publish().
 *
 * Must be called after mqtt_start() returns so the MQTT client is ready.
 *
 * @param sht3x     Pointer to an initialised SHT3x device descriptor.
 * @param ds3231    Pointer to an initialised DS3231 device descriptor.
 * @param device_id Resolved device identifier (used to build MQTT topics).
 *
 * @return ESP_OK if the task was created, ESP_FAIL otherwise.
 */
esp_err_t sensor_task_start(sht3x_t *sht3x, ds3231_t *ds3231, const char *device_id);
