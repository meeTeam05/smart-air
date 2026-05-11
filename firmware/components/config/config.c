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

#include <string.h>

static const char *TAG = "config";

/* ── Private namespace / key constants ──────────────────────────────────── */

/* Device / MQTT namespace */
#define NS_DEVICE "device"          /* 6 chars — within 15-char NVS limit */
#define KEY_DEVICE_ID "device_id"   /* 9 chars */
#define KEY_SECRET_KEY "secret_key" /* 10 chars */
#define KEY_BROKER_URI "broker_uri" /* 10 chars */

/* Gas sensor R0 NVS keys (namespace NS_DEVICE) */
#define KEY_R0_CO "r0_co"
#define KEY_R0_NO2 "r0_no2"

/* ── MQTT / device credential API ───────────────────────────────────────── */

esp_err_t config_get_mqtt_creds(char *broker_uri_buf,
                                size_t broker_uri_len,
                                char *device_id_buf,
                                size_t device_id_len,
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

    /* device_id — NVS first, fall back to Kconfig */
    if (err == ESP_OK) {
        esp_err_t r = nvs_get_str(h, KEY_DEVICE_ID, device_id_buf, &device_id_len);
        if (r == ESP_ERR_NVS_NOT_FOUND) {
            strlcpy(device_id_buf, CONFIG_SA_DEVICE_ID, device_id_len);
        } else if (r != ESP_OK) {
            ESP_LOGE(TAG, "read device_id failed: %s", esp_err_to_name(r));
            nvs_close(h);
            return r;
        }
    } else {
        strlcpy(device_id_buf, CONFIG_SA_DEVICE_ID, device_id_len);
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

esp_err_t config_set_mqtt_creds(const char *device_id, const char *secret_key)
{
    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_DEVICE, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "nvs_open(%s) failed: %s", NS_DEVICE, esp_err_to_name(err));
        return err;
    }

    err = nvs_set_str(h, KEY_DEVICE_ID, device_id);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "set device_id failed: %s", esp_err_to_name(err));
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

/* ── Device ID resolution ───────────────────────────────────────────────── */

void config_resolve_device_id(const char *input, char *out, size_t out_len)
{
    if (input != NULL && input[0] != '\0') {
        snprintf(out, out_len, "%s", input);
    } else {
        uint8_t mac[6];
        esp_read_mac(mac, ESP_MAC_WIFI_STA);
        snprintf(out, out_len, "%02x:%02x:%02x:%02x:%02x:%02x", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    }
}

/* ── Gas sensor R0 persistence ──────────────────────────────────────────── */

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

/* ── Self-test (enabled only when SA_CONFIG_SELF_TEST=y) ─────────────────── */

#ifdef CONFIG_SA_CONFIG_SELF_TEST
void config_self_test(void)
{
    ESP_LOGI(TAG, "Self-test: start");

    /* Use a dedicated test namespace to avoid polluting production data */
    const char *NS_TEST = "config_test";
    const char *TEST_DEV_ID = "test-dev-001";
    const char *TEST_SECRET = "test-secret-99";

    /* --- Write --- */
    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_TEST, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Self-test FAIL: nvs_open: %s", esp_err_to_name(err));
        return;
    }
    nvs_set_str(h, KEY_DEVICE_ID, TEST_DEV_ID);
    nvs_set_str(h, KEY_SECRET_KEY, TEST_SECRET);
    nvs_commit(h);
    nvs_close(h);

    /* --- Read back --- */
    char dev_id_buf[64] = {0};
    char secret_buf[64] = {0};
    size_t dev_id_len = sizeof(dev_id_buf);
    size_t secret_len = sizeof(secret_buf);

    err = nvs_open(NS_TEST, NVS_READONLY, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Self-test FAIL: nvs_open for read: %s", esp_err_to_name(err));
        return;
    }
    nvs_get_str(h, KEY_DEVICE_ID, dev_id_buf, &dev_id_len);
    nvs_get_str(h, KEY_SECRET_KEY, secret_buf, &secret_len);
    nvs_close(h);

    /* --- Verify --- */
    bool pass = (strcmp(dev_id_buf, TEST_DEV_ID) == 0) && (strcmp(secret_buf, TEST_SECRET) == 0);
    if (pass) {
        ESP_LOGI(TAG, "Self-test PASS");
    } else {
        ESP_LOGE(TAG, "Self-test FAIL: got device_id='%s' secret='%s'", dev_id_buf, secret_buf);
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
