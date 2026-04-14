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

/* ── Compile-time constants ──────────────────────────────────────────────── */

/** BLE advertising name (base, without MAC suffix) */
#define DEVICE_NAME "SMART_AIR"

/** Firmware version string */
#define FIRMWARE_VERSION CONFIG_FIRMWARE_VERSION

/** BLE provisioning name prefix */
#define PROV_NAME_PREFIX CONFIG_SA_PROV_NAME_PREFIX

/** MQTT broker URI — Kconfig default, overridable via NVS */
#define SA_MQTT_BROKER_URI CONFIG_SA_MQTT_BROKER_URI

/** Wi-Fi connect timeout in milliseconds */
#define SA_WIFI_CONNECT_TIMEOUT_MS CONFIG_SA_WIFI_CONNECT_TIMEOUT_MS

/** I2C bus pin and timing configuration */
#define SA_I2C_SDA_PIN CONFIG_SA_I2C_SDA_PIN
#define SA_I2C_SCL_PIN CONFIG_SA_I2C_SCL_PIN
#define SA_I2C_FREQ_HZ 400000 /* HW-01: fixed 400 kHz — do not change */
#define SA_I2C_TIMEOUT_MS CONFIG_SA_I2C_TIMEOUT_MS

/** Onboard RGB LED (WS2812 at GPIO38 on DevKitC-1) */
#define SA_LED_PIN CONFIG_SA_LED_PIN

/** NVS namespace + keys for Wi-Fi provisioning (shared with ble_prov.c) */
#define NVS_NAMESPACE "wifi_prov"
#define NVS_KEY_SSID "ssid"
#define NVS_KEY_PASS "password"
#define NVS_KEY_DONE "done"

/* ── NVS credential API ──────────────────────────────────────────────────── */

/**
 * @brief Read Wi-Fi credentials from NVS (namespace "wifi_prov").
 *
 * @param ssid_buf  Output buffer for SSID — must be at least 64 bytes.
 * @param ssid_len  Size of ssid_buf.
 * @param pass_buf  Output buffer for password — must be at least 64 bytes.
 * @param pass_len  Size of pass_buf.
 * @return ESP_OK on success, ESP_ERR_NVS_NOT_FOUND if not provisioned, or an NVS error.
 */
esp_err_t config_get_wifi_creds(char *ssid_buf, size_t ssid_len, char *pass_buf, size_t pass_len);

/**
 * @brief Write Wi-Fi credentials to NVS (namespace "wifi_prov") and commit.
 *
 * @param ssid      Null-terminated SSID string.
 * @param password  Null-terminated password string.
 * @return ESP_OK on success, or an NVS error.
 */
esp_err_t config_set_wifi_creds(const char *ssid, const char *password);

/**
 * @brief Read MQTT credentials from NVS (namespace "device").
 *
 * Falls back to Kconfig defaults (CONFIG_SA_MQTT_BROKER_URI, CONFIG_SA_DEVICE_ID,
 * CONFIG_SA_MQTT_SECRET_KEY) if a key is not found in NVS.
 *
 * @param broker_uri_buf  Output buffer for broker URI — at least 128 bytes.
 * @param broker_uri_len  Size of broker_uri_buf.
 * @param device_id_buf   Output buffer for device ID — at least 64 bytes.
 * @param device_id_len   Size of device_id_buf.
 * @param secret_key_buf  Output buffer for secret key — at least 64 bytes.
 * @param secret_key_len  Size of secret_key_buf.
 * @return ESP_OK on success, or an NVS error.
 */
esp_err_t config_get_mqtt_creds(char *broker_uri_buf,
                                size_t broker_uri_len,
                                char *device_id_buf,
                                size_t device_id_len,
                                char *secret_key_buf,
                                size_t secret_key_len);

/**
 * @brief Write MQTT device credentials (device_id + secret_key) to NVS and commit.
 *
 * @param device_id   Null-terminated device ID string.
 * @param secret_key  Null-terminated secret key string.
 * @return ESP_OK on success, or an NVS error.
 */
esp_err_t config_set_mqtt_creds(const char *device_id, const char *secret_key);

/**
 * @brief Return true if Wi-Fi credentials are stored in NVS (provisioning complete).
 */
bool config_is_provisioned(void);

#ifdef CONFIG_SA_CONFIG_SELF_TEST
/**
 * @brief Run NVS write/read roundtrip self-test (only when SA_CONFIG_SELF_TEST=y).
 *
 * Writes known test values, reads them back, verifies match, then erases them.
 * Logs PASS or FAIL. Does not affect production namespaces.
 */
void config_self_test(void);
#endif
