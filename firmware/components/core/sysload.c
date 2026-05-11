/**
 * @file sysload.c
 * 
 * @brief System initialisation and boot orchestration.
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
#include "mqtt.h"
#include "i2cdev.h"
#include "sht3x.h"
#include "ds3231.h"
#include "adc_bus.h"
#include "gm702b.h"
#include "gm102b.h"
#include "led.h"
#include "factory_reset.h"
#include "sensor_task.h"
#include "httpd.h"
#include "ota.h"

#include "sysload.h"

static const char *TAG = "sysload";

/* File-scope sensor handles — kept alive after sysload_init task exits */
#if CONFIG_SA_ENABLE_SHT3X
static sht3x_t s_sht3x_dev;
#endif
#if CONFIG_SA_ENABLE_DS3231
static ds3231_t s_ds3231_dev;
#endif
#if CONFIG_SA_ENABLE_CO_SENSOR
static gm702b_t s_co_dev;
#endif
#if CONFIG_SA_ENABLE_NO2_SENSOR
static gm102b_t s_no2_dev;
#endif

/* ── Gas sensor calibration MQTT command callbacks ──────────────────────── */
/* NOTE: Blocks ~1s (20 ADC samples × 50 ms) inside MQTT event thread.
 * Acceptable because calibration is rare, manual, user-initiated.
 * Future refactor: post to queue → dedicated calibrate task. */

#if CONFIG_SA_ENABLE_CO_SENSOR
static esp_err_t handle_calibrate_co(const char *type, const char *json_payload)
{
    (void)type; (void)json_payload;
    esp_err_t err = gm702b_calibrate(&s_co_dev);
    if (err == ESP_OK) {
        return config_save_gas_r0("co", s_co_dev.r0);
    }
    ESP_LOGE(TAG, "CO calibration failed: %s", esp_err_to_name(err));
    return err;
}
#endif

#if CONFIG_SA_ENABLE_NO2_SENSOR
static esp_err_t handle_calibrate_no2(const char *type, const char *json_payload)
{
    (void)type; (void)json_payload;
    esp_err_t err = gm102b_calibrate(&s_no2_dev);
    if (err == ESP_OK) {
        return config_save_gas_r0("no2", s_no2_dev.r0);
    }
    ESP_LOGE(TAG, "NO2 calibration failed: %s", esp_err_to_name(err));
    return err;
}
#endif

/* Time sync callback (app -> MQTT -> DS3231) */

#if CONFIG_SA_ENABLE_DS3231
static void on_time_sync(uint32_t ts)
{
    esp_err_t err = ds3231_set_timestamp(&s_ds3231_dev, ts);
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "DS3231 time updated: %lu", (unsigned long)ts);
    } else {
        ESP_LOGW(TAG, "DS3231 set_timestamp failed: %s", esp_err_to_name(err));
    }
}
#else
static void on_time_sync(uint32_t ts)
{
    ESP_LOGI(TAG, "DS3231 disabled — set_time(%lu) acknowledged, no RTC write", (unsigned long)ts);
}
#endif

void sysload_init(void)
{
    /* 0 — LED (init first so status is visible immediately) */
    ESP_ERROR_CHECK(led_init());
    led_set_state(LED_STATE_BOOT);

    /* 0.5 — Factory reset button (early so it works in every boot phase) */
#if CONFIG_SA_ENABLE_FACTORY_RESET
    {
        esp_err_t err = factory_reset_init((gpio_num_t)CONFIG_SA_FACTORY_RESET_PIN);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "factory_reset_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }
#endif

    /* 1 — NVS init (required by Wi-Fi and BLE provisioning) */
    {
        esp_err_t err = nvs_flash_init();
        if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
            ESP_ERROR_CHECK(nvs_flash_erase());
            err = nvs_flash_init();
        }
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "nvs_flash_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    /* 2 — Network stack (must precede wifi_sta_init) */
    {
        esp_err_t err = esp_netif_init();
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "esp_netif_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
        err = esp_event_loop_create_default();
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "esp_event_loop_create_default failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    /* 3 — I2C bus (shared by SHT3x and DS3231, HW-01: 400 kHz) */
    /* Only init bus if at least one I2C device is enabled. Add to this guard
     * when new I2C devices are added. */
#if CONFIG_SA_ENABLE_SHT3X || CONFIG_SA_ENABLE_DS3231
    {
        esp_err_t err = i2c_bus_init(I2C_NUM_0, (gpio_num_t)SA_I2C_SDA_PIN, (gpio_num_t)SA_I2C_SCL_PIN, SA_I2C_FREQ_HZ);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "i2c_bus_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }
#endif

    /* 4 — SHT3x temperature/humidity sensor (addr 0x44, ADDR pin low — HW-04) */
#if CONFIG_SA_ENABLE_SHT3X
    esp_err_t sht_err = sht3x_init_desc(
        &s_sht3x_dev, SHT3X_I2C_ADDR_GND, I2C_NUM_0, (gpio_num_t)SA_I2C_SDA_PIN, (gpio_num_t)SA_I2C_SCL_PIN);
    if (sht_err == ESP_OK)
        sht_err = i2c_dev_init(&s_sht3x_dev.i2c_dev);
    if (sht_err == ESP_OK)
        sht_err = sht3x_init(&s_sht3x_dev);
    if (sht_err != ESP_OK) {
        ESP_LOGW(TAG, "SHT3x init failed (%s) — sensor unavailable", esp_err_to_name(sht_err));
    }
#endif

    /* 5 — DS3231 RTC (addr 0x68 — HW-04) */
#if CONFIG_SA_ENABLE_DS3231
    esp_err_t rtc_err =
        ds3231_init_desc(&s_ds3231_dev, I2C_NUM_0, (gpio_num_t)SA_I2C_SDA_PIN, (gpio_num_t)SA_I2C_SCL_PIN);
    if (rtc_err == ESP_OK)
        rtc_err = i2c_dev_init(&s_ds3231_dev.i2c_dev);
    if (rtc_err != ESP_OK) {
        ESP_LOGW(TAG, "DS3231 init failed (%s) — RTC unavailable", esp_err_to_name(rtc_err));
    }
#endif

    /* 5.5 — ADC bus + gas sensors (analog, WiFi-safe ADC1 only) */
#if CONFIG_SA_ENABLE_CO_SENSOR || CONFIG_SA_ENABLE_NO2_SENSOR
    {
        esp_err_t err = adc_bus_init();
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "adc_bus_init failed (%s) — gas sensors unavailable", esp_err_to_name(err));
        }
    }
#endif

#if CONFIG_SA_ENABLE_CO_SENSOR
    esp_err_t co_err = gm702b_init(&s_co_dev, (adc_channel_t)SA_CO_ADC_CHANNEL,
                                   SA_GAS_SENSOR_RL_OHM, SA_GAS_SENSOR_VC_V);
    if (co_err == ESP_OK) {
        config_load_gas_r0("co", &s_co_dev.r0, &s_co_dev.calibrated);
        if (!s_co_dev.calibrated) {
            ESP_LOGW(TAG, "CO sensor not calibrated — send type:calibrate_co to calibrate");
        }
        mqtt_register_command_handler("calibrate_co", handle_calibrate_co);
    } else {
        ESP_LOGW(TAG, "GM702B CO init failed (%s) — CO unavailable", esp_err_to_name(co_err));
    }
#endif

#if CONFIG_SA_ENABLE_NO2_SENSOR
    esp_err_t no2_err = gm102b_init(&s_no2_dev, (adc_channel_t)SA_NO2_ADC_CHANNEL,
                                    SA_GAS_SENSOR_RL_OHM, SA_GAS_SENSOR_VC_V);
    if (no2_err == ESP_OK) {
        config_load_gas_r0("no2", &s_no2_dev.r0, &s_no2_dev.calibrated);
        if (!s_no2_dev.calibrated) {
            ESP_LOGW(TAG, "NO2 sensor not calibrated — send type:calibrate_no2 to calibrate");
        }
        mqtt_register_command_handler("calibrate_no2", handle_calibrate_no2);
    } else {
        ESP_LOGW(TAG, "GM102B NO2 init failed (%s) — NO2 unavailable", esp_err_to_name(no2_err));
    }
#endif

    /* 6 — Wi-Fi station (no connect yet) */
    {
        esp_err_t err = wifi_sta_init();
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "wifi_sta_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

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
    {
        esp_err_t err = ble_prov_load_credentials(ssid, sizeof(ssid), password, sizeof(password));
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "ble_prov_load_credentials failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

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

    /* 9 — MQTT client (TLS, connects async in background task) */
    char broker_uri[128] = {0};
    char device_id[64] = {0};
    char secret_key[64] = {0};
    {
        esp_err_t err = config_get_mqtt_creds(
            broker_uri, sizeof(broker_uri), device_id, sizeof(device_id), secret_key, sizeof(secret_key));
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "config_get_mqtt_creds failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }
    /* 9.1 — Register time sync callback before mqtt_start to avoid race:
     *        broker may deliver a queued set_time command immediately on connect */
    mqtt_register_time_sync_cb(on_time_sync);
    {
        esp_err_t err = mqtt_start(broker_uri, device_id, secret_key);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "mqtt_start failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    /* Resolve display device_id once: use config value or fall back to MAC */
    char resolved_id[64] = {0};
    config_resolve_device_id(device_id, resolved_id, sizeof(resolved_id));

    /* 9.5 — HTTP server (non-fatal: device operates without it) */
    {
        char ip_str[16] = {0};
        esp_netif_ip_info_t ip_info = {0};
        esp_netif_t *netif = esp_netif_get_handle_from_ifkey("WIFI_STA_DEF");
        if (netif != NULL && esp_netif_get_ip_info(netif, &ip_info) == ESP_OK) {
            snprintf(ip_str, sizeof(ip_str), IPSTR, IP2STR(&ip_info.ip));
        }
        esp_err_t err = httpd_server_start(resolved_id, ip_str);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "httpd_server_start failed (%s) — continuing without HTTP server", esp_err_to_name(err));
        }
    }

    /* 9.6 — OTA task (non-fatal: device operates without OTA capability) */
    {
        esp_err_t err = ota_task_start(resolved_id);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "ota_task_start failed (%s) — OTA unavailable", esp_err_to_name(err));
        }
    }

    /* 10 — Sensor polling task (publishes telemetry every SA_SENSOR_POLLING_INTERVAL ms) */
#if CONFIG_SA_ENABLE_SHT3X || CONFIG_SA_ENABLE_DS3231 || CONFIG_SA_ENABLE_CO_SENSOR || CONFIG_SA_ENABLE_NO2_SENSOR
    {
        bool any_ok = false;
        sht3x_t  *sht_ptr = NULL;
        ds3231_t *rtc_ptr = NULL;
        gm702b_t *co_ptr  = NULL;
        gm102b_t *no2_ptr = NULL;
#if CONFIG_SA_ENABLE_SHT3X
        if (sht_err == ESP_OK) { any_ok = true; sht_ptr = &s_sht3x_dev; }
#endif
#if CONFIG_SA_ENABLE_DS3231
        if (rtc_err == ESP_OK) { any_ok = true; rtc_ptr = &s_ds3231_dev; }
#endif
#if CONFIG_SA_ENABLE_CO_SENSOR
        if (co_err == ESP_OK)  { any_ok = true; co_ptr  = &s_co_dev; }
#endif
#if CONFIG_SA_ENABLE_NO2_SENSOR
        if (no2_err == ESP_OK) { any_ok = true; no2_ptr = &s_no2_dev; }
#endif
        if (any_ok) {
            ESP_ERROR_CHECK(sensor_task_start(sht_ptr, rtc_ptr, co_ptr, no2_ptr, resolved_id));
        } else {
            ESP_LOGW(TAG, "All enabled sensors failed init — sensor_task not started");
        }
    }
#else
    ESP_LOGI(TAG, "No sensors enabled — sensor_task not started");
#endif

    /* 11 — Validate OTA firmware after all subsystems running (SEC-03) */
    ota_validate_and_commit();

    vTaskDelete(NULL);
}
