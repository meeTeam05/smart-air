/**
 * @file config.c
 *
 * @brief NVS credential read/write API for Wi-Fi and MQTT configuration.
 *
 * NVS namespaces used:
 *   "wifi_prov" — Wi-Fi SSID, password, provisioning flag (shared with ble_prov.c)
 *   "device"    — device ID, MQTT secret key, broker URI
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "config.h"

#include "nvs.h"
#include "nvs_flash.h"
#include "esp_log.h"

#include <string.h>

static const char *TAG = "config";

/* ── Private namespace / key constants ──────────────────────────────────── */

/* WiFi namespace — must match NVS_NAMESPACE in config.h and ble_prov.c usage */
#define NS_WIFI NVS_NAMESPACE /* "wifi_prov" */
#define KEY_SSID NVS_KEY_SSID /* "ssid"     */
#define KEY_PASS NVS_KEY_PASS /* "password" */
#define KEY_DONE NVS_KEY_DONE /* "done"     */

/* Device / MQTT namespace */
#define NS_DEVICE "device"          /* 6 chars — within 15-char NVS limit */
#define KEY_DEVICE_ID "device_id"   /* 9 chars */
#define KEY_SECRET_KEY "secret_key" /* 10 chars */
#define KEY_BROKER_URI "broker_uri" /* 10 chars */

/* ── Wi-Fi credential API ────────────────────────────────────────────────── */

esp_err_t config_get_wifi_creds(char *ssid_buf, size_t ssid_len, char *pass_buf, size_t pass_len)
{
    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_WIFI, NVS_READONLY, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "nvs_open(%s) failed: %s", NS_WIFI, esp_err_to_name(err));
        return err;
    }

    err = nvs_get_str(h, KEY_SSID, ssid_buf, &ssid_len);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "read SSID failed: %s", esp_err_to_name(err));
        nvs_close(h);
        return err;
    }

    err = nvs_get_str(h, KEY_PASS, pass_buf, &pass_len);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "read password failed: %s", esp_err_to_name(err));
    }

    nvs_close(h);
    return err;
}

esp_err_t config_set_wifi_creds(const char *ssid, const char *password)
{
    nvs_handle_t h;
    esp_err_t err = nvs_open(NS_WIFI, NVS_READWRITE, &h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "nvs_open(%s) failed: %s", NS_WIFI, esp_err_to_name(err));
        return err;
    }

    err = nvs_set_str(h, KEY_SSID, ssid);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "set SSID failed: %s", esp_err_to_name(err));
        nvs_close(h);
        return err;
    }

    err = nvs_set_str(h, KEY_PASS, password);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "set password failed: %s", esp_err_to_name(err));
        nvs_close(h);
        return err;
    }

    err = nvs_set_u8(h, KEY_DONE, 1);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "set done flag failed: %s", esp_err_to_name(err));
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

bool config_is_provisioned(void)
{
    nvs_handle_t h;
    if (nvs_open(NS_WIFI, NVS_READONLY, &h) != ESP_OK) {
        return false;
    }
    uint8_t flag = 0;
    nvs_get_u8(h, KEY_DONE, &flag);
    nvs_close(h);
    return flag == 1;
}

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
