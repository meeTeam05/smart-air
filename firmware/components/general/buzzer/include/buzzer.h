/**
 * @file buzzer.h
 * 
 * @brief Buzzer driver header.
 * 
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#pragma once

#include "esp_err.h"

#include <stdint.h>

/**
 * @brief Initialize the buzzer.
 * 
 * @return ESP_OK on success, or an error code.
 */
esp_err_t buzzer_init(void);

/**
 * @brief Beep the buzzer for a specified duration.
 * 
 * @param duration_ms Duration of the beep in milliseconds.
 * 
 * @note This function is non-blocking and returns immediately.
 */
void buzzer_beep_ms(uint32_t duration_ms);
