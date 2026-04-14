/**
 * @file led.h
 *
 * @brief WS2812 RGB LED driver — boot/BLE/WiFi/online/OTA/error state machine.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#pragma once

#include "esp_err.h"

typedef enum {
    LED_STATE_BOOT,           /**< white blink  — boot / init                      */
    LED_STATE_BLE,            /**< blue blink   — BLE awaiting app                 */
    LED_STATE_WIFI,           /**< yellow blink — connecting to WiFi               */
    LED_STATE_ONLINE,         /**< green static — WiFi (+ MQTT) ok                 */
    LED_STATE_OTA,            /**< purple blink — OTA in progress                  */
    LED_STATE_ERROR,          /**< red static   — fatal error, no recovery         */
    LED_STATE_FACTORY_RESET,  /**< red blink    — reset hold in progress, cancellable */
    LED_STATE_OFF,
} led_state_t;

/**
 * @brief Initialise the WS2812 RMT channel and start the blink timer.
 *
 * Must be called once before led_set_state(). Uses SA_LED_PIN from config.h.
 *
 * @return ESP_OK on success.
 */
esp_err_t led_init(void);

/**
 * @brief Change the current LED state (thread-safe).
 *
 * Safe to call from any task or ISR context.
 */
void led_set_state(led_state_t state);
