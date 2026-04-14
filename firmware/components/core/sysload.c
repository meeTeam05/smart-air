/**
 * @file sysload.c
 * 
 * @brief System load header.
 * 
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "esp_netif.h"
#include "esp_event.h"
#include "esp_log.h"

#include "ble_prov.h"
#include "wifi.h"
#include "i2cdev.h"
#include "sht3x.h"
#include "ds3231.h"
#include "led.h"

#include "sysload.h"

static const char *TAG = "sysload";

void sysload_init(void)
{
    /* 0 — LED (init first so status is visible immediately) */
    ESP_ERROR_CHECK(led_init());
    led_set_state(LED_STATE_BOOT);

    /* 1 — NVS init (required by Wi-Fi and BLE provisioning) */
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    /* 2 — Network stack (must precede wifi_sta_init) */
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    /* 3 — I2C bus (shared by SHT3x and DS3231, HW-01: 400 kHz) */
    ESP_ERROR_CHECK(i2c_bus_init(I2C_NUM_0, (gpio_num_t)SA_I2C_SDA_PIN, (gpio_num_t)SA_I2C_SCL_PIN, SA_I2C_FREQ_HZ));

    /* 4 — SHT3x temperature/humidity sensor (addr 0x44, ADDR pin low — HW-04) */
    static sht3x_t sht3x_dev;
    esp_err_t sht_err = sht3x_init_desc(
        &sht3x_dev, SHT3X_I2C_ADDR_GND, I2C_NUM_0, (gpio_num_t)SA_I2C_SDA_PIN, (gpio_num_t)SA_I2C_SCL_PIN);
    if (sht_err == ESP_OK)
        sht_err = i2c_dev_init(&sht3x_dev.i2c_dev);
    if (sht_err == ESP_OK)
        sht_err = sht3x_init(&sht3x_dev);
    if (sht_err != ESP_OK) {
        ESP_LOGW(TAG, "SHT3x init failed (%s) — sensor unavailable", esp_err_to_name(sht_err));
    }

    /* 5 — DS3231 RTC (addr 0x68 — HW-04) */
    static ds3231_t ds3231_dev;
    esp_err_t rtc_err =
        ds3231_init_desc(&ds3231_dev, I2C_NUM_0, (gpio_num_t)SA_I2C_SDA_PIN, (gpio_num_t)SA_I2C_SCL_PIN);
    if (rtc_err == ESP_OK)
        rtc_err = i2c_dev_init(&ds3231_dev.i2c_dev);
    if (rtc_err != ESP_OK) {
        ESP_LOGW(TAG, "DS3231 init failed (%s) — RTC unavailable", esp_err_to_name(rtc_err));
    }

    /* 6 — Wi-Fi station (no connect yet) */
    ESP_ERROR_CHECK(wifi_sta_init());

    /* 7 — BLE provisioning on first boot */
    if (!ble_prov_is_provisioned()) {
        ESP_LOGI(TAG, "Not provisioned — starting BLE provisioning");
        led_set_state(LED_STATE_BLE);
        esp_err_t err = ble_prov_start();
        ble_prov_stop();

        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "Provisioning failed — rebooting in 5 s");
            vTaskDelay(pdMS_TO_TICKS(5000));
            esp_restart();
        }
    }

    /* 8 — Load stored credentials and connect Wi-Fi (skip if already connected via ble_prov) */
    char ssid[64] = {0};
    char password[64] = {0};
    ESP_ERROR_CHECK(ble_prov_load_credentials(ssid, sizeof(ssid), password, sizeof(password)));

    if (!wifi_sta_is_connected()) {
        led_set_state(LED_STATE_WIFI);
        ESP_LOGI(TAG, "Connecting to Wi-Fi SSID: %s", ssid);
        esp_err_t err = wifi_sta_connect(ssid, password, CONFIG_SA_WIFI_CONNECT_TIMEOUT_MS);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "Wi-Fi connect failed (%s) — re-provisioning on next boot", esp_err_to_name(err));
            ble_prov_reset();
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    led_set_state(LED_STATE_ONLINE);
    ESP_LOGI(TAG, "Wi-Fi connected — TODO: start MQTT");

    /* 9 — TODO: mqtt_start(CONFIG_SA_MQTT_BROKER_URI); */

    vTaskDelete(NULL);
}
