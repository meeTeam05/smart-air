/**
 * @file config.c
 *
 * @brief NVS credential read/write API for Wi-Fi and MQTT configuration.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "config.h"

#include "nvs.h"
#include "nvs_flash.h"
#include "esp_log.h"
#include "esp_mac.h"

#include <ctype.h>
#include <string.h>

static const char *TAG = "config";

/* Private namespace / key constants */

/* Device / MQTT namespace */
#define NS_DEVICE      "device"     /* 6 chars — within 15-char NVS limit */
#define KEY_SECRET_KEY "secret_key" /* 10 chars */
#define KEY_BROKER_URI "broker_uri" /* 10 chars */

/* Gas sensor R0 NVS keys (namespace NS_DEVICE) */
#define KEY_R0_CO  "r0_co"
#define KEY_R0_NO2 "r0_no2"

static bool is_mac_format(const char *input);
static bool copy_lowercase_mac(const char *input, char *out, size_t out_len);
static esp_err_t copy_device_mac(char *out, size_t out_len);

/* MQTT / device credential API */

esp_err_t config_get_mqtt_creds(char *broker_uri_buf,
                                size_t broker_uri_len,
                                char *secret_key_buf,
                                size_t secret_key_len)
{
    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_DEVICE, NVS_READONLY, &h);
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND) {
        ESP_LOGE(TAG, "nvs_open(%s) failed: %s", NS_DEVICE, esp_err_to_name(err));
        return err;
    }

    /* broker_uri — NVS first, fall back to Kconfig */
    if (err == ESP_OK) {
        esp_err_t r = nvs_get_str(h, KEY_BROKER_URI, broker_uri_buf, &broker_uri_len);
        if (r == ESP_ERR_NVS_NOT_FOUND) {
            strlcpy(broker_uri_buf, CONFIG_SA_MQTT_BROKER_URI, broker_uri_len);
        } else if (r != ESP_OK) {
            ESP_LOGE(TAG, "read broker_uri failed: %s", esp_err_to_name(r));
            nvs_close(h);
            return r;
        }
    } else {
        strlcpy(broker_uri_buf, CONFIG_SA_MQTT_BROKER_URI, broker_uri_len);
    }

    /* secret_key — NVS first, fall back to Kconfig */
    if (err == ESP_OK) {
        esp_err_t r = nvs_get_str(h, KEY_SECRET_KEY, secret_key_buf, &secret_key_len);
        if (r == ESP_ERR_NVS_NOT_FOUND) {
            strlcpy(secret_key_buf, CONFIG_SA_MQTT_SECRET_KEY, secret_key_len);
        } else if (r != ESP_OK) {
            ESP_LOGE(TAG, "read secret_key failed: %s", esp_err_to_name(r));
            nvs_close(h);
            return r;
        }
    } else {
        strlcpy(secret_key_buf, CONFIG_SA_MQTT_SECRET_KEY, secret_key_len);
    }

    if (err == ESP_OK) {
        nvs_close(h);
    }
    return ESP_OK;
}

esp_err_t config_get_device_id(char *out, size_t out_len)
{
    return copy_device_mac(out, out_len);
}

esp_err_t config_set_mqtt_config(const char *broker_uri, const char *device_id, const char *secret_key)
{
    char actual_device_id[18] = {0};
    char normalized_device_id[18] = {0};
    if (!is_mac_format(device_id)
        || !copy_lowercase_mac(device_id, normalized_device_id, sizeof(normalized_device_id))
        || copy_device_mac(actual_device_id, sizeof(actual_device_id)) != ESP_OK
        || strcmp(normalized_device_id, actual_device_id) != 0
        || secret_key == NULL
        || secret_key[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    if (broker_uri != NULL && broker_uri[0] != '\0' && strncmp(broker_uri, "mqtts://", 8) != 0) {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_DEVICE, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "nvs_open(%s) failed: %s", NS_DEVICE, esp_err_to_name(err));
        return err;
    }

    if (broker_uri != NULL && broker_uri[0] != '\0') {
        err = nvs_set_str(h, KEY_BROKER_URI, broker_uri);
        if (err != ESP_OK) {
            ESP_LOGE(TAG, "set broker_uri failed: %s", esp_err_to_name(err));
            nvs_close(h);
            return err;
        }
    }

    err = nvs_erase_key(h, "device_id");
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND) {
        ESP_LOGE(TAG, "erase legacy device_id failed: %s", esp_err_to_name(err));
        nvs_close(h);
        return err;
    }

    err = nvs_set_str(h, KEY_SECRET_KEY, secret_key);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "set secret_key failed: %s", esp_err_to_name(err));
        nvs_close(h);
        return err;
    }

    err = nvs_commit(h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "nvs_commit failed: %s", esp_err_to_name(err));
    }

    nvs_close(h);
    return err;
}

/* Device ID resolution */

static bool is_hex_nibble(char c)
{
    return isxdigit((unsigned char)c) != 0;
}

static bool is_mac_format(const char *input)
{
    if (input == NULL || strlen(input) != 17) {
        return false;
    }

    for (size_t i = 0; i < 17; i++) {
        if (i == 2 || i == 5 || i == 8 || i == 11 || i == 14) {
            if (input[i] != ':') {
                return false;
            }
            continue;
        }

        if (!is_hex_nibble(input[i])) {
            return false;
        }
    }

    return true;
}

static bool copy_lowercase_mac(const char *input, char *out, size_t out_len)
{
    if (input == NULL || out == NULL || out_len < 18 || strlen(input) != 17) {
        return false;
    }

    for (size_t i = 0; i < 17; i++) {
        out[i] = (char)tolower((unsigned char)input[i]);
    }
    out[17] = '\0';
    return true;
}

static esp_err_t copy_device_mac(char *out, size_t out_len)
{
    if (out == NULL || out_len < 18) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    snprintf(out, out_len, "%02x:%02x:%02x:%02x:%02x:%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return ESP_OK;
}

/* Gas sensor R0 persistence */

esp_err_t config_load_gas_r0(const char *sensor_name, float *r0, bool *calibrated)
{
    *r0 = 0.0f;
    *calibrated = false;

    const char *key = (sensor_name[0] == 'c') ? KEY_R0_CO : KEY_R0_NO2;

    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_DEVICE, NVS_READONLY, &h);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK; /* namespace not yet created — not calibrated */
    }
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "load_gas_r0(%s): nvs_open failed: %s", sensor_name, esp_err_to_name(err));
        return err;
    }

    size_t len = sizeof(float);
    err = nvs_get_blob(h, key, r0, &len);
    nvs_close(h);

    if (err == ESP_OK && len == sizeof(float) && *r0 > 0.0f) {
        *calibrated = true;
        ESP_LOGI(TAG, "load_gas_r0(%s): R0 = %.0f ohm", sensor_name, *r0);
    } else if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK; /* not calibrated yet — not an error */
    } else if (err != ESP_OK) {
        ESP_LOGE(TAG, "load_gas_r0(%s): nvs_get_blob failed: %s", sensor_name, esp_err_to_name(err));
        return err;
    }

    return ESP_OK;
}

esp_err_t config_save_gas_r0(const char *sensor_name, float r0)
{
    const char *key = (sensor_name[0] == 'c') ? KEY_R0_CO : KEY_R0_NO2;

    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_DEVICE, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "save_gas_r0(%s): nvs_open failed: %s", sensor_name, esp_err_to_name(err));
        return err;
    }

    err = nvs_set_blob(h, key, &r0, sizeof(float));
    if (err == ESP_OK) {
        err = nvs_commit(h);
    }
    nvs_close(h);

    if (err == ESP_OK) {
        ESP_LOGI(TAG, "save_gas_r0(%s): R0 = %.0f ohm saved", sensor_name, r0);
    } else {
        ESP_LOGE(TAG, "save_gas_r0(%s): write failed: %s", sensor_name, esp_err_to_name(err));
    }
    return err;
}

/* Self-test (enabled only when SA_CONFIG_SELF_TEST=y) */

#ifdef CONFIG_SA_CONFIG_SELF_TEST
void config_self_test(void)
{
    ESP_LOGI(TAG, "Self-test: start");

    /* Use a dedicated test namespace to avoid polluting production data */
    const char *NS_TEST = "config_test";
    const char *TEST_BROKER = "mqtts://mqtt.minhnhat05.xyz:8883";
    const char *TEST_SECRET = "test-secret-99";

    /* --- Write --- */
    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_TEST, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Self-test FAIL: nvs_open: %s", esp_err_to_name(err));
        return;
    }
    nvs_set_str(h, KEY_BROKER_URI, TEST_BROKER);
    nvs_set_str(h, KEY_SECRET_KEY, TEST_SECRET);
    nvs_commit(h);
    nvs_close(h);

    /* --- Read back --- */
    char broker_buf[128] = {0};
    char secret_buf[64] = {0};
    size_t broker_len = sizeof(broker_buf);
    size_t secret_len = sizeof(secret_buf);

    err = nvs_open(NS_TEST, NVS_READONLY, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Self-test FAIL: nvs_open for read: %s", esp_err_to_name(err));
        return;
    }
    nvs_get_str(h, KEY_BROKER_URI, broker_buf, &broker_len);
    nvs_get_str(h, KEY_SECRET_KEY, secret_buf, &secret_len);
    nvs_close(h);

    /* --- Verify --- */
    bool pass = (strcmp(broker_buf, TEST_BROKER) == 0) && (strcmp(secret_buf, TEST_SECRET) == 0);
    if (pass) {
        ESP_LOGI(TAG, "Self-test PASS");
    } else {
        ESP_LOGE(TAG, "Self-test FAIL: got broker='%s' secret='%s'", broker_buf, secret_buf);
    }

    /* --- Erase test namespace --- */
    err = nvs_open(NS_TEST, NVS_READWRITE, &h);
    if (err == ESP_OK) {
        nvs_erase_all(h);
        nvs_commit(h);
        nvs_close(h);
    }
}
#endif /* CONFIG_SA_CONFIG_SELF_TEST */
