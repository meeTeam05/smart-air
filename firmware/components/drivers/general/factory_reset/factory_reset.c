/**
 * @file factory_reset.c
 *
 * @brief Physical factory reset button — 50 ms polling, hold-to-reset.
 *
 * State machine (runs in factory_reset_task):
 *
 *   IDLE  → button not pressed, hold_ms == 0
 *   HOLD  → button pressed, 0 < hold_ms < SA_FACTORY_RESET_HOLD_MS
 *             LED switches to FACTORY_RESET (red blink) after 1 s
 *   RESET → hold_ms >= SA_FACTORY_RESET_HOLD_MS → do_factory_reset()
 *
 * Releasing during HOLD restores the LED state that was active before hold
 * started and returns to IDLE — no side effects.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "factory_reset.h"

#include "ble_prov.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "led.h"
#include "mqtt.h"
#include "wifi.h"

#include "sdkconfig.h"

static const char *TAG = "factory_reset";

#if CONFIG_SA_ENABLE_FACTORY_RESET

/* Hold duration after which LED feedback begins (1 s) */
#define FEEDBACK_THRESHOLD_MS 1000

/* Polling interval */
#define POLL_MS 50

static gpio_num_t s_gpio;

/* ── Reset sequence ──────────────────────────────────────────────────────── */

static void do_factory_reset(void)
{
    ESP_LOGW(TAG, "Factory reset triggered — erasing provisioning data");

    /* Solid red: point of no return */
    led_set_state(LED_STATE_ERROR);

    /* 1. Erase WiFi provisioning NVS namespace — device re-provisions on boot */
    ble_prov_reset();

    /* 2. Clean WiFi shutdown */
    wifi_sta_deinit();

    /* 3. Clean MQTT shutdown (suppresses spurious reconnects during reboot) */
    mqtt_stop();

    /* Brief settle for peripheral shutdown */
    vTaskDelay(pdMS_TO_TICKS(500));

    ESP_LOGI(TAG, "Rebooting into BLE provisioning mode");
    esp_restart();
    /* Never reached */
}

/* ── Polling task ────────────────────────────────────────────────────────── */

static void factory_reset_task(void *arg)
{
    uint32_t     hold_ms     = 0;
    bool         was_holding = false;
    led_state_t  saved_state = LED_STATE_ONLINE;

    while (1) {
        vTaskDelay(pdMS_TO_TICKS(POLL_MS));

        /* Active-low: GPIO low = button pressed */
        int level = gpio_get_level(s_gpio);

        if (level != 0) {
            /* Button released or not pressed */
            if (was_holding) {
                /* User cancelled — restore previous LED state */
                ESP_LOGI(TAG, "Hold cancelled after %lu ms", (unsigned long)hold_ms);
                led_set_state(saved_state);
            }
            hold_ms     = 0;
            was_holding = false;
            continue;
        }

        /* Button is held down */
        hold_ms += POLL_MS;

        /* Start giving visible feedback after FEEDBACK_THRESHOLD_MS */
        if (hold_ms >= FEEDBACK_THRESHOLD_MS && !was_holding) {
            /* Snapshot current LED state so we can restore it on cancel */
            saved_state = led_get_state();
            was_holding = true;
            led_set_state(LED_STATE_FACTORY_RESET);
            ESP_LOGI(TAG, "Hold detected — keep holding for factory reset (%d ms total)",
                     CONFIG_SA_FACTORY_RESET_HOLD_MS);
        }

        if (hold_ms >= (uint32_t)CONFIG_SA_FACTORY_RESET_HOLD_MS) {
            do_factory_reset(); /* never returns */
        }
    }
}

#endif /* CONFIG_SA_ENABLE_FACTORY_RESET */

/* ── Public API ──────────────────────────────────────────────────────────── */

esp_err_t factory_reset_init(gpio_num_t gpio)
{
#if CONFIG_SA_ENABLE_FACTORY_RESET
    s_gpio = gpio;

    gpio_config_t cfg = {
        .pin_bit_mask = (1ULL << gpio),
        .mode         = GPIO_MODE_INPUT,
        .pull_up_en   = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type    = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "gpio_config failed (%s)", esp_err_to_name(err));
        return err;
    }

    /* Core 1, Priority 4, stack 3072 B — lightweight polling task */
    BaseType_t rc = xTaskCreatePinnedToCore(
        factory_reset_task, "fr_task", 3072, NULL, 4, NULL, APP_CPU_NUM);
    if (rc != pdPASS) {
        ESP_LOGE(TAG, "xTaskCreatePinnedToCore failed");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "init OK (GPIO%d, hold=%d ms)", gpio, CONFIG_SA_FACTORY_RESET_HOLD_MS);
    return ESP_OK;
#else
    (void)gpio;
    return ESP_OK;
#endif
}
