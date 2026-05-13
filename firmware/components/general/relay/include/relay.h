#pragma once

#include "esp_err.h"
#include <stdbool.h>

#define RELAY_CHANNEL_COUNT 3

esp_err_t relay_init(const char *device_id);
esp_err_t relay_set(int channel, bool on);
esp_err_t relay_get(int channel, bool *on);
esp_err_t relay_get_all(bool states[RELAY_CHANNEL_COUNT]);
esp_err_t relay_force_all_off(void);
