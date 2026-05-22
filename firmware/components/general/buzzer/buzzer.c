/**
 * @file buzzer.c
 * 
 * @brief Buzzer driver implementation.
 * 
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "buzzer.h"

#include "config.h"

#include <stdbool.h>

#if SA_ENABLE_BUZZER

#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"

#include "driver/ledc.h"

#define BUZZER_FREQ_HZ      2000
#define BUZZER_DUTY_RES     LEDC_TIMER_10_BIT
#define BUZZER_DUTY_HALF    (1U << 9)
#define BUZZER_LEDC_MODE    LEDC_LOW_SPEED_MODE
#define BUZZER_LEDC_TIMER   LEDC_TIMER_1
#define BUZZER_LEDC_CHANNEL LEDC_CHANNEL_0

static const char *TAG = "buzzer";
static bool s_initialized = false;
static StaticSemaphore_t s_buzzer_lock_buf;
static SemaphoreHandle_t s_buzzer_lock;
static portMUX_TYPE s_buzzer_lock_guard = portMUX_INITIALIZER_UNLOCKED;

static SemaphoreHandle_t ensure_buzzer_lock(void)
{
    if (s_buzzer_lock != NULL) {
        return s_buzzer_lock;
    }

    portENTER_CRITICAL(&s_buzzer_lock_guard);
    if (s_buzzer_lock == NULL) {
        s_buzzer_lock = xSemaphoreCreateMutexStatic(&s_buzzer_lock_buf);
    }
    portEXIT_CRITICAL(&s_buzzer_lock_guard);

    return s_buzzer_lock;
}

static esp_err_t buzzer_init_locked(void)
{
    if (s_initialized) {
        return ESP_OK;
    }

    ledc_timer_config_t timer_cfg = {
        .speed_mode = BUZZER_LEDC_MODE,
        .duty_resolution = BUZZER_DUTY_RES,
        .timer_num = BUZZER_LEDC_TIMER,
        .freq_hz = BUZZER_FREQ_HZ,
        .clk_cfg = LEDC_AUTO_CLK,
    };

    esp_err_t err = ledc_timer_config(&timer_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "ledc_timer_config failed (%s)", esp_err_to_name(err));
        return err;
    }

    ledc_channel_config_t ch_cfg = {
        .gpio_num = CONFIG_SA_BUZZER_PIN,
        .speed_mode = BUZZER_LEDC_MODE,
        .channel = BUZZER_LEDC_CHANNEL,
        .timer_sel = BUZZER_LEDC_TIMER,
        .duty = 0,
        .hpoint = 0,
    };

    err = ledc_channel_config(&ch_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "ledc_channel_config failed (%s)", esp_err_to_name(err));
        return err;
    }

    s_initialized = true;
    ESP_LOGI(TAG, "init OK (GPIO%d, %d Hz)", CONFIG_SA_BUZZER_PIN, BUZZER_FREQ_HZ);
    return ESP_OK;
}

esp_err_t buzzer_init(void)
{
    SemaphoreHandle_t lock = ensure_buzzer_lock();
    if (lock == NULL) {
        return ESP_ERR_NO_MEM;
    }

    if (xSemaphoreTake(lock, portMAX_DELAY) != pdTRUE) {
        return ESP_FAIL;
    }

    esp_err_t err = buzzer_init_locked();
    xSemaphoreGive(lock);
    return err;
}

void buzzer_beep_ms(uint32_t duration_ms)
{
    if (duration_ms == 0) {
        return;
    }

    SemaphoreHandle_t lock = ensure_buzzer_lock();
    if (lock == NULL) {
        ESP_LOGE(TAG, "buzzer lock init failed");
        return;
    }

    if (xSemaphoreTake(lock, portMAX_DELAY) != pdTRUE) {
        ESP_LOGE(TAG, "buzzer lock take failed");
        return;
    }

    if (!s_initialized) {
        esp_err_t init_err = buzzer_init_locked();
        if (init_err != ESP_OK) {
            ESP_LOGE(TAG, "buzzer_init failed before beep (%s)", esp_err_to_name(init_err));
            xSemaphoreGive(lock);
            return;
        }
    }

    esp_err_t err = ledc_set_duty(BUZZER_LEDC_MODE, BUZZER_LEDC_CHANNEL, BUZZER_DUTY_HALF);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "ledc_set_duty(on) failed (%s)", esp_err_to_name(err));
        xSemaphoreGive(lock);
        return;
    }

    err = ledc_update_duty(BUZZER_LEDC_MODE, BUZZER_LEDC_CHANNEL);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "ledc_update_duty(on) failed (%s)", esp_err_to_name(err));
        xSemaphoreGive(lock);
        return;
    }

    vTaskDelay(pdMS_TO_TICKS(duration_ms));

    err = ledc_set_duty(BUZZER_LEDC_MODE, BUZZER_LEDC_CHANNEL, 0);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "ledc_set_duty(off) failed (%s)", esp_err_to_name(err));
        xSemaphoreGive(lock);
        return;
    }

    err = ledc_update_duty(BUZZER_LEDC_MODE, BUZZER_LEDC_CHANNEL);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "ledc_update_duty(off) failed (%s)", esp_err_to_name(err));
        xSemaphoreGive(lock);
        return;
    }

    xSemaphoreGive(lock);
}

#else

esp_err_t buzzer_init(void)
{
    return ESP_OK;
}

void buzzer_beep_ms(uint32_t duration_ms)
{
    (void)duration_ms;
}

#endif
