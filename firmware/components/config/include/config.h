/**
 * @file config.h
 *
 * @brief Project-wide configuration constants and NVS credential management API.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#pragma once

#include "esp_err.h"
#include "sdkconfig.h"
#include <stdbool.h>
#include <stddef.h>

/* Compile-time constants */

/** BLE advertising name (base, without MAC suffix) */
#define DEVICE_NAME "SMART_AIR"

/** Firmware version string */
#define FIRMWARE_VERSION CONFIG_FIRMWARE_VERSION

#define SA_DEMO_NO_PERIPHERALS CONFIG_SA_DEMO_NO_PERIPHERALS

#if CONFIG_SA_DEMO_NO_PERIPHERALS
#define SA_ENABLE_SHT3X         0
#define SA_ENABLE_DS3231        0
#define SA_ENABLE_CO_SENSOR     0
#define SA_ENABLE_NO2_SENSOR    0
#define SA_ENABLE_ILI9225       0
#define SA_ENABLE_SD_CARD       0
#define SA_ENABLE_RELAYS        0
#define SA_ENABLE_BUZZER        0
#define SA_ENABLE_LED           0
#define SA_ENABLE_FACTORY_RESET 0
#else
#define SA_ENABLE_SHT3X         CONFIG_SA_ENABLE_SHT3X
#define SA_ENABLE_DS3231        CONFIG_SA_ENABLE_DS3231
#define SA_ENABLE_CO_SENSOR     CONFIG_SA_ENABLE_CO_SENSOR
#define SA_ENABLE_NO2_SENSOR    CONFIG_SA_ENABLE_NO2_SENSOR
#define SA_ENABLE_ILI9225       CONFIG_SA_ENABLE_ILI9225
#define SA_ENABLE_SD_CARD       CONFIG_SA_ENABLE_SD_CARD
#define SA_ENABLE_RELAYS        CONFIG_SA_ENABLE_RELAYS
#define SA_ENABLE_BUZZER        CONFIG_SA_ENABLE_BUZZER
#define SA_ENABLE_LED           CONFIG_SA_ENABLE_LED
#define SA_ENABLE_FACTORY_RESET CONFIG_SA_ENABLE_FACTORY_RESET
#endif

/** Sensor polling interval (in seconds) */
#define SA_SENSOR_POLLING_INTERVAL CONFIG_SA_SENSOR_POLLING_INTERVAL * 1000 /* convert to ms */

/** I2C configuration */
#define SA_I2C_SDA_PIN    CONFIG_SA_I2C_SDA_PIN
#define SA_I2C_SCL_PIN    CONFIG_SA_I2C_SCL_PIN
#define SA_I2C_FREQ_HZ    CONFIG_SA_I2C_FREQ_HZ
#define SA_I2C_TIMEOUT_MS CONFIG_SA_I2C_TIMEOUT_MS

/** Gas sensor ADC pins + channel mapping (ESP32-S3 ADC1: CH = GPIO - 1) */
#define SA_CO_ANALOG_PIN  CONFIG_SA_CO_ANALOG_PIN
#define SA_NO2_ANALOG_PIN CONFIG_SA_NO2_ANALOG_PIN

/** Gas sensor ADC channels */
#define SA_CO_ADC_CHANNEL    (CONFIG_SA_CO_ANALOG_PIN - 1)
#define SA_NO2_ADC_CHANNEL   (CONFIG_SA_NO2_ANALOG_PIN - 1)
#define SA_GAS_SENSOR_RL_OHM 10000.0f
#define SA_GAS_SENSOR_VC_V   3.3f

/** Onboard RGB LED (WS2812 at GPIO38 on DevKitC-1) */
#define SA_LED_PIN CONFIG_SA_LED_PIN

/** NVS namespace + keys for Wi-Fi provisioning (shared with ble_prov.c) */
#define SA_NVS_WIFI_NAMESPACE "wifi_prov"
#define SA_NVS_KEY_SSID       "ssid"
#define SA_NVS_KEY_PASS       "password"
#define SA_NVS_KEY_DONE       "done"

/* NVS credential API */

/**
 * @brief Read MQTT credentials from NVS (namespace "device").
 *
 * @param broker_uri_buf  Output buffer for broker URI — at least 128 bytes.
 * @param broker_uri_len  Size of broker_uri_buf.
 * @param secret_key_buf  Output buffer for secret key — at least 64 bytes.
 * @param secret_key_len  Size of secret_key_buf.
 *
 * @return ESP_OK on success, or an NVS error.
 *
 * @note Falls back to Kconfig defaults (CONFIG_SA_MQTT_BROKER_URI,
 *       CONFIG_SA_MQTT_SECRET_KEY) if a key is not found in NVS.
 */
esp_err_t config_get_mqtt_creds(char *broker_uri_buf,
                                size_t broker_uri_len,
                                char *secret_key_buf,
                                size_t secret_key_len);

/**
 * @brief Resolve the immutable device identifier from the Wi-Fi STA MAC.
 *
 * @param out      Output buffer for device ID.
 * @param out_len  Size of output buffer (at least 18 bytes for MAC format).
 *
 * @return ESP_OK on success, ESP_ERR_INVALID_ARG for invalid output buffer.
 */
esp_err_t config_get_device_id(char *out, size_t out_len);

/**
 * @brief Write MQTT broker override and secret key to NVS and commit.
 *
 * @param broker_uri  Optional broker URI override. Pass NULL or "" to keep the existing/default URI.
 * @param device_id   Null-terminated device ID string in MAC format. Must match the device STA MAC.
 * @param secret_key  Null-terminated per-device MQTT secret from the server.
 *
 * @return ESP_OK on success, ESP_ERR_INVALID_ARG on invalid contract fields, or an NVS error.
 */
esp_err_t config_set_mqtt_config(const char *broker_uri, const char *device_id, const char *secret_key);

/**
 * @brief Load persisted gas sensor R0 baseline from NVS.
 *
 * @param sensor_name  "co" or "no2" — used as NVS key suffix.
 * @param r0           Output: R0 value in ohm.
 * @param calibrated   Output: true if a persisted R0 was found.
 *
 * @return ESP_OK on success or key not found (calibrated=false), error otherwise.
 */
esp_err_t config_load_gas_r0(const char *sensor_name, float *r0, bool *calibrated);

/**
 * @brief Persist gas sensor R0 baseline to NVS.
 *
 * @param sensor_name  "co" or "no2".
 * @param r0           R0 value in ohm from sensor calibration.
 *
 * @return ESP_OK on success, NVS error otherwise.
 */
esp_err_t config_save_gas_r0(const char *sensor_name, float r0);

/**
 * @brief Device mode query shared across components to avoid dependency cycles.
 *
 * @return true when device mode is ON and relay commands are allowed.
 */
bool device_mode_get(void);

/**
 * @brief Sensor task publish gate shared across components to avoid dependency cycles.
 *
 * @return true when sensor task is allowed to publish readings (device mode ON and not in factory reset).
 */
bool sensor_task_get_enabled(void);

/**
 * @brief Set sensor task publish enabled/disabled.
 *
 * @param enabled  true to enable publishes, false to disable.
 */
void sensor_task_set_enabled(bool enabled);

#ifdef CONFIG_SA_CONFIG_SELF_TEST

/**
 * @brief Run NVS write/read roundtrip self-test (only when SA_CONFIG_SELF_TEST=y).
 *
 * Writes known test values, reads them back, verifies match, then erases them.
 * Logs PASS or FAIL. Does not affect production namespaces.
 */
void config_self_test(void);

#endif
