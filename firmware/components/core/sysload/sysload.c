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
#include "buzzer.h"
#include "relay.h"
#include "device_mode.h"

#include "cJSON.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#include "sysload.h"

static const char *TAG = "sysload";
static const uint32_t MIN_VALID_UNIX_TS = 946684800UL;

static int build_month_index(const char *month)
{
    static const char *months[] = {
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    };

    for (int i = 0; i < 12; i++) {
        if (strncmp(month, months[i], 3) == 0) {
            return i;
        }
    }

    return -1;
}

static uint32_t build_time_fallback_ts(void)
{
    char month[4] = {0};
    int day = 0;
    int year = 0;
    int hour = 0;
    int minute = 0;
    int second = 0;

    if (sscanf(__DATE__, "%3s %d %d", month, &day, &year) != 3) {
        return MIN_VALID_UNIX_TS;
    }
    if (sscanf(__TIME__, "%d:%d:%d", &hour, &minute, &second) != 3) {
        return MIN_VALID_UNIX_TS;
    }

    int month_index = build_month_index(month);
    if (month_index < 0) {
        return MIN_VALID_UNIX_TS;
    }

    struct tm build_tm = {
        .tm_sec = second,
        .tm_min = minute,
        .tm_hour = hour,
        .tm_mday = day,
        .tm_mon = month_index,
        .tm_year = year - 1900,
        .tm_isdst = -1,
    };

    time_t build_time = mktime(&build_tm);
    if (build_time <= 0) {
        return MIN_VALID_UNIX_TS;
    }

    return (uint32_t)build_time;
}

static void sync_system_clock(uint32_t ts, const char *reason)
{
    struct timeval tv = {
        .tv_sec = (time_t)ts,
        .tv_usec = 0,
    };

    if (settimeofday(&tv, NULL) == 0) {
        ESP_LOGI(TAG, "System clock updated from %s: %lu", reason, (unsigned long)ts);
    } else {
        ESP_LOGW(TAG, "settimeofday failed for %s (errno=%d)", reason, errno);
    }
}

static void ensure_system_clock_seeded(void)
{
    time_t now = time(NULL);
    if (now >= (time_t)MIN_VALID_UNIX_TS) {
        return;
    }

    sync_system_clock(build_time_fallback_ts(), "build time");
}

/* File-scope sensor handles — kept alive after sysload_init task exits */
#if SA_ENABLE_SHT3X
static sht3x_t s_sht3x_dev;
#endif
#if SA_ENABLE_DS3231
static ds3231_t s_ds3231_dev;
#endif
#if SA_ENABLE_CO_SENSOR
static gm702b_t s_co_dev;
#endif
#if SA_ENABLE_NO2_SENSOR
static gm102b_t s_no2_dev;
#endif

/* Gas sensor calibration MQTT command callbacks */
/* NOTE: Blocks ~1s (20 ADC samples × 50 ms) inside MQTT event thread.
 * Acceptable because calibration is rare, manual, user-initiated.
 * Future refactor: post to queue -> dedicated calibrate task. */

#if SA_ENABLE_CO_SENSOR
static esp_err_t handle_calibrate_co(const char *type, const char *json_payload)
{
    (void)type;
    (void)json_payload;
    esp_err_t err = gm702b_calibrate(&s_co_dev);
    if (err == ESP_OK) {
        return config_save_gas_r0("co", s_co_dev.r0);
    }
    ESP_LOGE(TAG, "CO calibration failed: %s", esp_err_to_name(err));
    return err;
}
#endif

#if SA_ENABLE_NO2_SENSOR
static esp_err_t handle_calibrate_no2(const char *type, const char *json_payload)
{
    (void)type;
    (void)json_payload;
    esp_err_t err = gm102b_calibrate(&s_no2_dev);
    if (err == ESP_OK) {
        return config_save_gas_r0("no2", s_no2_dev.r0);
    }
    ESP_LOGE(TAG, "NO2 calibration failed: %s", esp_err_to_name(err));
    return err;
}
#endif

#if SA_ENABLE_RELAYS
static esp_err_t handle_relay_set(const char *type, const char *json_payload)
{
    (void)type;

    if (json_payload == NULL) {
        ESP_LOGW(TAG, "relay_set command: missing payload");
        return ESP_ERR_INVALID_ARG;
    }

    cJSON *root = cJSON_ParseWithLength(json_payload, strlen(json_payload));
    if (root == NULL) {
        ESP_LOGW(TAG, "relay_set command: invalid JSON payload");
        return ESP_ERR_INVALID_ARG;
    }

    cJSON *j_relay = cJSON_GetObjectItemCaseSensitive(root, "relay");
    cJSON *j_state = cJSON_GetObjectItemCaseSensitive(root, "state");

    if (!cJSON_IsNumber(j_relay) || !cJSON_IsBool(j_state)) {
        ESP_LOGW(TAG, "relay_set command: invalid relay/state fields");
        cJSON_Delete(root);
        return ESP_ERR_INVALID_ARG;
    }

    int channel = (int)j_relay->valuedouble;
    if ((double)channel != j_relay->valuedouble) {
        ESP_LOGW(TAG, "relay_set command: relay must be integer");
        cJSON_Delete(root);
        return ESP_ERR_INVALID_ARG;
    }

    bool on = cJSON_IsTrue(j_state);
    cJSON_Delete(root);

    esp_err_t err = relay_set(channel, on);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "relay_set command failed: %s", esp_err_to_name(err));
    }

    return err;
}
#endif

static esp_err_t handle_device_mode(const char *type, const char *json_payload)
{
    (void)type;

    if (json_payload == NULL) {
        ESP_LOGW(TAG, "device_mode command: missing payload");
        return ESP_ERR_INVALID_ARG;
    }

    cJSON *root = cJSON_ParseWithLength(json_payload, strlen(json_payload));
    if (root == NULL) {
        ESP_LOGW(TAG, "device_mode command: invalid JSON payload");
        return ESP_ERR_INVALID_ARG;
    }

    cJSON *j_mode = cJSON_GetObjectItemCaseSensitive(root, "mode");
    if (!cJSON_IsString(j_mode)) {
        ESP_LOGW(TAG, "device_mode command: mode must be string");
        cJSON_Delete(root);
        return ESP_ERR_INVALID_ARG;
    }

    bool mode_on = false;
    if (strcmp(j_mode->valuestring, "on") == 0) {
        mode_on = true;
    } else if (strcmp(j_mode->valuestring, "off") == 0) {
        mode_on = false;
    } else {
        ESP_LOGW(TAG, "device_mode command: unsupported mode value");
        cJSON_Delete(root);
        return ESP_ERR_INVALID_ARG;
    }

    cJSON_Delete(root);

    esp_err_t err = device_mode_set(mode_on);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "device_mode command failed: %s", esp_err_to_name(err));
    }

    return err;
}

/* Time sync callback (app -> MQTT -> DS3231) */

#if SA_ENABLE_DS3231
static void on_time_sync(uint32_t ts)
{
    sync_system_clock(ts, "set_time");

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
    sync_system_clock(ts, "set_time");
    ESP_LOGI(TAG, "DS3231 disabled — set_time(%lu) acknowledged, system clock updated", (unsigned long)ts);
}
#endif

void sysload_init(void)
{
    /* 0 — LED (init first so status is visible immediately) */
    ESP_ERROR_CHECK(led_init());
    led_set_state(LED_STATE_BOOT);

    /* 0.5 — Factory reset button (early so it works in every boot phase) */
#if SA_ENABLE_FACTORY_RESET
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
#if SA_ENABLE_SHT3X || SA_ENABLE_DS3231
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
#if SA_ENABLE_SHT3X
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
#if SA_ENABLE_DS3231
    esp_err_t rtc_err =
        ds3231_init_desc(&s_ds3231_dev, I2C_NUM_0, (gpio_num_t)SA_I2C_SDA_PIN, (gpio_num_t)SA_I2C_SCL_PIN);
    if (rtc_err == ESP_OK)
        rtc_err = i2c_dev_init(&s_ds3231_dev.i2c_dev);
    if (rtc_err != ESP_OK) {
        ESP_LOGW(TAG, "DS3231 init failed (%s) — RTC unavailable", esp_err_to_name(rtc_err));
    }
#endif

    /* 5.5 — ADC bus + gas sensors (analog, WiFi-safe ADC1 only) */
#if SA_ENABLE_CO_SENSOR || SA_ENABLE_NO2_SENSOR
    {
        esp_err_t err = adc_bus_init();
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "adc_bus_init failed (%s) — gas sensors unavailable", esp_err_to_name(err));
        }
    }
#endif

#if SA_ENABLE_CO_SENSOR
    esp_err_t co_err =
        gm702b_init(&s_co_dev, (adc_channel_t)SA_CO_ADC_CHANNEL, SA_GAS_SENSOR_RL_OHM, SA_GAS_SENSOR_VC_V);
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

#if SA_ENABLE_NO2_SENSOR
    esp_err_t no2_err =
        gm102b_init(&s_no2_dev, (adc_channel_t)SA_NO2_ADC_CHANNEL, SA_GAS_SENSOR_RL_OHM, SA_GAS_SENSOR_VC_V);
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
            ESP_LOGE(TAG, "Wi-Fi connect failed (%s) — running full factory reset", esp_err_to_name(err));
            err = factory_reset_run();
            if (err != ESP_OK) {
                ESP_LOGE(TAG, "factory_reset_run failed (%s) — rebooting anyway", esp_err_to_name(err));
            }
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    led_set_state(LED_STATE_WIFI);

    /* 9 — Resolve immutable device ID and runtime config */
    char broker_uri[128] = {0};
    char resolved_id[18] = {0};
    char secret_key[64] = {0};
    {
        esp_err_t err = config_get_device_id(resolved_id, sizeof(resolved_id));
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "config_get_device_id failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }

        err = config_get_mqtt_creds(broker_uri, sizeof(broker_uri), secret_key, sizeof(secret_key));
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "config_get_mqtt_creds failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }
    ensure_system_clock_seeded();

    /* 9.1 — Local provisioning HTTP API (must exist before first MQTT login) */
    {
        char ip_str[16] = {0};
        wifi_sta_get_ip(ip_str, sizeof(ip_str));

        esp_err_t err = httpd_server_start(resolved_id, ip_str);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "httpd_server_start failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    if (secret_key[0] == '\0') {
        ESP_LOGW(TAG, "MQTT secret_key not provisioned yet — waiting for local POST /api/config");
        vTaskDelete(NULL);
    }

    /* 9.2 — Runtime control bootstrap (buzzer -> relay -> mode -> MQTT handlers) */
    {
        esp_err_t err = buzzer_init();
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "buzzer_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }

#if SA_ENABLE_RELAYS
        err = relay_init(resolved_id);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "relay_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
#endif

        err = device_mode_init(resolved_id);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "device_mode_init failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }

#if SA_ENABLE_RELAYS
        mqtt_register_command_handler("relay_set", handle_relay_set);
#endif
        mqtt_register_command_handler("device_mode", handle_device_mode);
    }

    /* 9.3 — Register time sync callback before mqtt_start to avoid race:
     *        broker may deliver a queued set_time command immediately on connect */
    mqtt_register_time_sync_cb(on_time_sync);

    /* 9.4 — Start MQTT */
    {
        esp_err_t err = mqtt_start(broker_uri, resolved_id, secret_key);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "mqtt_start failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    /* 9.5 — OTA task */
    {
        esp_err_t err = ota_task_start(resolved_id);
        if (err != ESP_OK) {
            led_set_state(LED_STATE_ERROR);
            ESP_LOGE(TAG, "ota_task_start failed (%s) — rebooting", esp_err_to_name(err));
            vTaskDelay(pdMS_TO_TICKS(2000));
            esp_restart();
        }
    }

    /* 10 — Sensor polling task (publishes telemetry every SA_SENSOR_POLLING_INTERVAL ms) */
#if SA_DEMO_NO_PERIPHERALS
    ESP_ERROR_CHECK(sensor_task_start(NULL, NULL, NULL, NULL, resolved_id));
#elif SA_ENABLE_SHT3X || SA_ENABLE_DS3231 || SA_ENABLE_CO_SENSOR || SA_ENABLE_NO2_SENSOR
    {
        bool any_ok = false;
        sht3x_t *sht_ptr = NULL;
        ds3231_t *rtc_ptr = NULL;
        gm702b_t *co_ptr = NULL;
        gm102b_t *no2_ptr = NULL;
#if SA_ENABLE_SHT3X
        if (sht_err == ESP_OK) {
            any_ok = true;
            sht_ptr = &s_sht3x_dev;
        }
#endif
#if SA_ENABLE_DS3231
        if (rtc_err == ESP_OK) {
            any_ok = true;
            rtc_ptr = &s_ds3231_dev;
        }
#endif
#if SA_ENABLE_CO_SENSOR
        if (co_err == ESP_OK) {
            any_ok = true;
            co_ptr = &s_co_dev;
        }
#endif
#if SA_ENABLE_NO2_SENSOR
        if (no2_err == ESP_OK) {
            any_ok = true;
            no2_ptr = &s_no2_dev;
        }
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
