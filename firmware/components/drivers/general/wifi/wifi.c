/**
 * @file wifi.c
 * 
 * @brief Wi-Fi station mode driver.
 * 
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "wifi.h"

#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_log.h"

#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"

#include <string.h>

#include "config.h"

static const char *TAG = "wifi_sta";

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1

static EventGroupHandle_t s_wifi_eg;
static esp_netif_t *s_netif;
static char s_ip[16];
static bool s_initialized;
static int s_reconnect_count;

#define WIFI_MAX_RECONNECT_ATTEMPTS 10

static void wifi_event_handler(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        xEventGroupClearBits(s_wifi_eg, WIFI_CONNECTED_BIT);
        xEventGroupSetBits(s_wifi_eg, WIFI_FAIL_BIT);

        if (s_reconnect_count < WIFI_MAX_RECONNECT_ATTEMPTS) {
            s_reconnect_count++;
            ESP_LOGW(TAG, "Disconnected — reconnect attempt %d/%d",
                     s_reconnect_count, WIFI_MAX_RECONNECT_ATTEMPTS);
            esp_wifi_connect();
        } else {
            ESP_LOGE(TAG, "Disconnected — max reconnect attempts reached, giving up");
        }

    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *ev = (ip_event_got_ip_t *)data;
        snprintf(s_ip, sizeof(s_ip), IPSTR, IP2STR(&ev->ip_info.ip));
        ESP_LOGI(TAG, "Got IP: %s", s_ip);
        s_reconnect_count = 0;
        xEventGroupClearBits(s_wifi_eg, WIFI_FAIL_BIT);
        xEventGroupSetBits(s_wifi_eg, WIFI_CONNECTED_BIT);
    }
}

esp_err_t wifi_sta_init(void)
{
    if (s_initialized) {
        return ESP_OK; /* idempotent */
    }

    s_wifi_eg = xEventGroupCreate();
    if (s_wifi_eg == NULL) {
        return ESP_ERR_NO_MEM;
    }

    s_netif = esp_netif_create_default_wifi_sta();
    if (s_netif == NULL) {
        return ESP_FAIL;
    }

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    esp_err_t err = esp_wifi_init(&cfg);
    if (err != ESP_OK) {
        return err;
    }

    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL, NULL));
    ESP_ERROR_CHECK(
        esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL, NULL));

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());

    s_initialized = true;
    ESP_LOGI(TAG, "Wi-Fi station initialized");
    return ESP_OK;
}

esp_err_t wifi_sta_connect(const char *ssid, const char *password, uint32_t timeout_ms)
{
    if (!s_initialized)
        return ESP_ERR_INVALID_STATE;
    if (ssid == NULL || password == NULL)
        return ESP_ERR_INVALID_ARG;

    /* Clear bits from any previous attempt */
    xEventGroupClearBits(s_wifi_eg, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT);

    wifi_config_t cfg = {0};
    strncpy((char *)cfg.sta.ssid, ssid, sizeof(cfg.sta.ssid) - 1);
    strncpy((char *)cfg.sta.password, password, sizeof(cfg.sta.password) - 1);
    cfg.sta.threshold.authmode = (*password == '\0') ? WIFI_AUTH_OPEN : WIFI_AUTH_WPA2_PSK;

    esp_err_t err = esp_wifi_set_config(WIFI_IF_STA, &cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "set_config failed: %s", esp_err_to_name(err));
        return err;
    }

    err = esp_wifi_connect();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_wifi_connect failed: %s", esp_err_to_name(err));
        return err;
    }

    EventBits_t bits =
        xEventGroupWaitBits(s_wifi_eg, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT, pdFALSE, pdFALSE, pdMS_TO_TICKS(timeout_ms));

    if (bits & WIFI_CONNECTED_BIT)
        return ESP_OK;
    if (bits & WIFI_FAIL_BIT)
        return ESP_FAIL;
    return ESP_ERR_TIMEOUT;
}

bool wifi_sta_is_connected(void)
{
    if (s_wifi_eg == NULL)
        return false;
    return (xEventGroupGetBits(s_wifi_eg) & WIFI_CONNECTED_BIT) != 0;
}

void wifi_sta_get_ip(char *buf, size_t len)
{
    if (buf == NULL || len == 0)
        return;
    strncpy(buf, s_ip, len - 1);
    buf[len - 1] = '\0';
}

esp_err_t wifi_sta_deinit(void)
{
    if (!s_initialized)
        return ESP_OK;

    ESP_ERROR_CHECK(esp_wifi_disconnect());
    ESP_ERROR_CHECK(esp_wifi_stop());
    ESP_ERROR_CHECK(esp_wifi_deinit());
    esp_netif_destroy(s_netif);
    s_netif = NULL;
    vEventGroupDelete(s_wifi_eg);
    s_wifi_eg = NULL;
    s_initialized = false;
    return ESP_OK;
}
