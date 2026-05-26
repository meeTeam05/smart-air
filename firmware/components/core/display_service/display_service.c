/**
 * @file display_service.c
 *
 * @brief LVGL host for the optional ILI9225 display.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "display_service.h"

#include "config.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "ili9225.h"
#include "lvgl.h"
#include "wifi.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#if SA_ENABLE_ILI9225

static const char *TAG = "display_service";

#define DISPLAY_LOGICAL_W 220
#define DISPLAY_LOGICAL_H 176
#define DISPLAY_NATIVE_W ILI9225_PHYS_W
#define DISPLAY_NATIVE_H ILI9225_PHYS_H
#define DISPLAY_BUF_LINES 16
#define DISPLAY_BUF_PIXELS (DISPLAY_LOGICAL_W * DISPLAY_BUF_LINES)
#define DISPLAY_TICK_MS 5
#define DISPLAY_TASK_DELAY_MS 10
#define DISPLAY_UI_REFRESH_MS 250
#define DISPLAY_TEXT_W 208
#define DISPLAY_MIN_VALID_UNIX_TS 946684800UL
#define DISPLAY_RELAY_COUNT 3
#define DISPLAY_SELF_TEST_TICK_MS 20
#define DISPLAY_INIT_WAIT_BASE_MS 2000
#define DISPLAY_INIT_WAIT_MARGIN_MS 500

#if SA_DISP_SELF_TEST
#define DISPLAY_SELF_TEST_SCREEN_COUNT 4U
#else
#define DISPLAY_SELF_TEST_SCREEN_COUNT 0U
#endif

typedef struct {
    display_boot_phase_t phase;
    bool mode_known;
    bool mode_on;
    bool relay_states[DISPLAY_RELAY_COUNT];
    display_sensor_snapshot_t sensor;
} display_state_t;

static SemaphoreHandle_t s_init_done = NULL;
static TaskHandle_t s_task = NULL;
static esp_timer_handle_t s_tick_timer = NULL;
static volatile bool s_ready = false;
static esp_err_t s_init_result = ESP_FAIL;
static portMUX_TYPE s_state_lock = portMUX_INITIALIZER_UNLOCKED;
static display_state_t s_state = {
    .phase = DISPLAY_BOOT_PHASE_BOOT,
};

static lv_disp_draw_buf_t s_draw_buf;
static lv_color_t *s_buf1 = NULL;
static lv_color_t *s_buf2 = NULL;
static uint8_t *s_swap_buf = NULL;

static lv_obj_t *s_title = NULL;
static lv_obj_t *s_status = NULL;
static lv_obj_t *s_sensor_1 = NULL;
static lv_obj_t *s_sensor_2 = NULL;
static lv_obj_t *s_footer = NULL;

static void lv_tick_cb(void *arg)
{
    (void)arg;
    lv_tick_inc(DISPLAY_TICK_MS);
}

static void snapshot_state(display_state_t *out)
{
    if (out == NULL) {
        return;
    }

    portENTER_CRITICAL(&s_state_lock);
    *out = s_state;
    portEXIT_CRITICAL(&s_state_lock);
}

static void set_centered_label_style(lv_obj_t *label)
{
    lv_obj_set_width(label, DISPLAY_TEXT_W);
    lv_label_set_long_mode(label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(label, LV_TEXT_ALIGN_CENTER, 0);
}

static void prepare_screen(lv_obj_t *scr, uint32_t bg_hex)
{
    lv_obj_set_style_bg_color(scr, lv_color_hex(bg_hex), 0);
    lv_obj_set_style_bg_opa(scr, LV_OPA_COVER, 0);
    lv_obj_set_style_pad_all(scr, 0, 0);
    lv_obj_clear_flag(scr, LV_OBJ_FLAG_SCROLLABLE);
}

static void build_screen(void)
{
    lv_obj_t *scr = lv_scr_act();
    prepare_screen(scr, 0xFFFFFF);

    s_title = lv_label_create(scr);
    set_centered_label_style(s_title);
    lv_label_set_text(s_title, "Smart Air");
    lv_obj_align(s_title, LV_ALIGN_TOP_MID, 0, 16);

    s_status = lv_label_create(scr);
    set_centered_label_style(s_status);
    lv_label_set_text(s_status, "Booting");
    lv_obj_align(s_status, LV_ALIGN_TOP_MID, 0, 52);

    s_sensor_1 = lv_label_create(scr);
    set_centered_label_style(s_sensor_1);
    lv_label_set_text(s_sensor_1, "");
    lv_obj_align(s_sensor_1, LV_ALIGN_TOP_MID, 0, 84);

    s_sensor_2 = lv_label_create(scr);
    set_centered_label_style(s_sensor_2);
    lv_label_set_text(s_sensor_2, "");
    lv_obj_align(s_sensor_2, LV_ALIGN_TOP_MID, 0, 108);

    s_footer = lv_label_create(scr);
    set_centered_label_style(s_footer);
    lv_obj_set_style_text_color(s_footer, lv_color_hex(0x666666), 0);
    lv_label_set_text(s_footer, "ILI9225 + LVGL");
    lv_obj_align(s_footer, LV_ALIGN_BOTTOM_MID, 0, -10);
}

#if SA_DISP_SELF_TEST
static void self_test_wait(uint32_t duration_ms)
{
    uint32_t elapsed_ms = 0;
    while (elapsed_ms < duration_ms) {
        lv_timer_handler();

        uint32_t step_ms = DISPLAY_SELF_TEST_TICK_MS;
        uint32_t remaining_ms = duration_ms - elapsed_ms;
        if (remaining_ms < step_ms) {
            step_ms = remaining_ms;
        }

        vTaskDelay(pdMS_TO_TICKS(step_ms));
        elapsed_ms += step_ms;
    }
}

static void self_test_fullscreen(uint32_t bg_hex, uint32_t fg_hex, const char *title, const char *footer)
{
    lv_obj_t *scr = lv_scr_act();
    lv_obj_clean(scr);
    prepare_screen(scr, bg_hex);

    lv_obj_t *title_label = lv_label_create(scr);
    set_centered_label_style(title_label);
    lv_obj_set_style_text_color(title_label, lv_color_hex(fg_hex), 0);
    lv_label_set_text(title_label, title);
    lv_obj_align(title_label, LV_ALIGN_CENTER, 0, -8);

    lv_obj_t *footer_label = lv_label_create(scr);
    set_centered_label_style(footer_label);
    lv_obj_set_style_text_color(footer_label, lv_color_hex(fg_hex), 0);
    lv_label_set_text(footer_label, footer);
    lv_obj_align(footer_label, LV_ALIGN_CENTER, 0, 22);

    lv_timer_handler();
    self_test_wait(SA_DISP_SELF_TEST_HOLD_MS);
}

static void self_test_corner_box(lv_obj_t *parent,
                                 lv_align_t align,
                                 lv_coord_t x_ofs,
                                 lv_coord_t y_ofs,
                                 uint32_t bg_hex,
                                 const char *text)
{
    lv_obj_t *box = lv_obj_create(parent);
    lv_obj_remove_style_all(box);
    lv_obj_set_size(box, 40, 28);
    lv_obj_set_style_bg_color(box, lv_color_hex(bg_hex), 0);
    lv_obj_set_style_bg_opa(box, LV_OPA_COVER, 0);
    lv_obj_set_style_radius(box, 4, 0);
    lv_obj_align(box, align, x_ofs, y_ofs);

    lv_obj_t *label = lv_label_create(box);
    lv_obj_set_style_text_color(label, lv_color_hex(0xFFFFFF), 0);
    lv_label_set_text(label, text);
    lv_obj_center(label);
}

static void self_test_orientation(void)
{
    lv_obj_t *scr = lv_scr_act();
    lv_obj_clean(scr);
    prepare_screen(scr, 0xFFFFFF);

    lv_obj_t *title_label = lv_label_create(scr);
    set_centered_label_style(title_label);
    lv_label_set_text(title_label, "Orientation test");
    lv_obj_align(title_label, LV_ALIGN_TOP_MID, 0, 12);

    self_test_corner_box(scr, LV_ALIGN_TOP_LEFT, 8, 42, 0xD32F2F, "TL");
    self_test_corner_box(scr, LV_ALIGN_TOP_RIGHT, -8, 42, 0x1976D2, "TR");
    self_test_corner_box(scr, LV_ALIGN_BOTTOM_LEFT, 8, -42, 0x388E3C, "BL");
    self_test_corner_box(scr, LV_ALIGN_BOTTOM_RIGHT, -8, -42, 0xF57C00, "BR");

    lv_obj_t *note_label = lv_label_create(scr);
    set_centered_label_style(note_label);
    lv_label_set_text(note_label, "Check corner labels and color order");
    lv_obj_align(note_label, LV_ALIGN_CENTER, 0, 0);

    lv_timer_handler();
    self_test_wait(SA_DISP_SELF_TEST_HOLD_MS);
}

static void run_self_test(void)
{
    ESP_LOGI(TAG, "running display self-test");
    self_test_fullscreen(0xD32F2F, 0xFFFFFF, "DISPLAY TEST", "RED");
    self_test_fullscreen(0x388E3C, 0xFFFFFF, "DISPLAY TEST", "GREEN");
    self_test_fullscreen(0x1976D2, 0xFFFFFF, "DISPLAY TEST", "BLUE");
    self_test_orientation();
    lv_obj_clean(lv_scr_act());
}
#endif

static void render_boot_phase(display_boot_phase_t phase)
{
    if (s_title == NULL || s_status == NULL || s_sensor_1 == NULL || s_sensor_2 == NULL || s_footer == NULL) {
        return;
    }

    const char *title = "Smart Air";
    const char *status = "Booting";

    switch (phase) {
    case DISPLAY_BOOT_PHASE_BOOT:
        status = "Starting system";
        break;
    case DISPLAY_BOOT_PHASE_BLE:
        title = "Provisioning";
        status = "Waiting for Wi-Fi setup";
        break;
    case DISPLAY_BOOT_PHASE_WIFI:
        title = "Wi-Fi";
        status = "Connecting to network";
        break;
    case DISPLAY_BOOT_PHASE_WAITING_CONFIG:
        title = "Provisioning";
        status = "Waiting for cloud secret";
        break;
    case DISPLAY_BOOT_PHASE_MQTT:
        title = "Cloud";
        status = "Connecting MQTT";
        break;
    case DISPLAY_BOOT_PHASE_READY:
        title = "Smart Air";
        status = "System online";
        break;
    default:
        break;
    }

    lv_label_set_text(s_title, title);
    lv_label_set_text(s_status, status);
    lv_label_set_text(s_sensor_1, "");
    lv_label_set_text(s_sensor_2, "");
    lv_label_set_text(s_footer, "ILI9225 + LVGL");
}

static void format_runtime_status(char *buf, size_t len, time_t now, bool wifi_connected, bool have_rssi, int rssi_dbm)
{
    if (now >= (time_t)DISPLAY_MIN_VALID_UNIX_TS) {
        struct tm tm_now = {0};
        localtime_r(&now, &tm_now);
        if (wifi_connected && have_rssi) {
            snprintf(buf,
                     len,
                     "%02d:%02d:%02d  Wi-Fi %ddBm",
                     tm_now.tm_hour,
                     tm_now.tm_min,
                     tm_now.tm_sec,
                     rssi_dbm);
            return;
        }
        snprintf(buf,
                 len,
                 "%02d:%02d:%02d  Wi-Fi %s",
                 tm_now.tm_hour,
                 tm_now.tm_min,
                 tm_now.tm_sec,
                 wifi_connected ? "on" : "off");
        return;
    }

    if (wifi_connected && have_rssi) {
        snprintf(buf, len, "Clock --  Wi-Fi %ddBm", rssi_dbm);
        return;
    }

    snprintf(buf, len, "Clock --  Wi-Fi %s", wifi_connected ? "on" : "off");
}

static void format_runtime_footer(char *buf, size_t len, const display_state_t *state)
{
    snprintf(buf,
             len,
             "Mode %s  Relays %d %d %d",
             state->mode_known ? (state->mode_on ? "ON" : "OFF") : "--",
             state->relay_states[0] ? 1 : 0,
             state->relay_states[1] ? 1 : 0,
             state->relay_states[2] ? 1 : 0);
}

static void render_runtime(const display_state_t *state, time_t now, bool wifi_connected, bool have_rssi, int rssi_dbm)
{
    if (state == NULL || s_title == NULL || s_status == NULL || s_sensor_1 == NULL || s_sensor_2 == NULL || s_footer == NULL) {
        return;
    }

    char status[48] = {0};
    char sensor_1[48] = {0};
    char sensor_2[48] = {0};
    char footer[48] = {0};

    format_runtime_status(status, sizeof(status), now, wifi_connected, have_rssi, rssi_dbm);
    format_runtime_footer(footer, sizeof(footer), state);

    if (state->mode_known && !state->mode_on) {
        strlcpy(sensor_1, "Sensors paused", sizeof(sensor_1));
        strlcpy(sensor_2, "CO --  NO2 --", sizeof(sensor_2));
    } else {
        if (state->sensor.have_temperature_humidity) {
            snprintf(sensor_1,
                     sizeof(sensor_1),
                     "T %.1fC  H %.1f%%",
                     (double)state->sensor.temperature_c,
                     (double)state->sensor.humidity_pct);
        } else {
            strlcpy(sensor_1, "T --  H --", sizeof(sensor_1));
        }

        char co_buf[16] = "--";
        char no2_buf[16] = "--";
        if (state->sensor.have_co) {
            snprintf(co_buf, sizeof(co_buf), "%.1fppm", (double)state->sensor.co_ppm);
        }
        if (state->sensor.have_no2) {
            snprintf(no2_buf, sizeof(no2_buf), "%.2fppm", (double)state->sensor.no2_ppm);
        }
        snprintf(sensor_2, sizeof(sensor_2), "CO %s  NO2 %s", co_buf, no2_buf);
    }

    lv_label_set_text(s_title, "Smart Air");
    lv_label_set_text(s_status, status);
    lv_label_set_text(s_sensor_1, sensor_1);
    lv_label_set_text(s_sensor_2, sensor_2);
    lv_label_set_text(s_footer, footer);
}

static void render_screen(void)
{
    display_state_t state;
    snapshot_state(&state);

    time_t now = time(NULL);
    bool wifi_connected = wifi_sta_is_connected();
    bool have_rssi = false;
    int rssi_dbm = 0;
    if (wifi_connected && wifi_sta_get_rssi(&rssi_dbm) == ESP_OK) {
        have_rssi = true;
    }

    if (state.phase == DISPLAY_BOOT_PHASE_READY) {
        render_runtime(&state, now, wifi_connected, have_rssi, rssi_dbm);
        return;
    }

    render_boot_phase(state.phase);
}

static void display_flush(lv_disp_drv_t *drv, const lv_area_t *area, lv_color_t *color_p)
{
    const size_t pixel_count = lv_area_get_size(area);
    const size_t byte_count = pixel_count * sizeof(lv_color_t);
    const uint8_t *tx = (const uint8_t *)color_p;

#if !defined(CONFIG_LV_COLOR_16_SWAP) || !CONFIG_LV_COLOR_16_SWAP
    for (size_t i = 0; i < pixel_count; i++) {
        const uint8_t *src = (const uint8_t *)&color_p[i];
        s_swap_buf[(i * 2U)] = src[1];
        s_swap_buf[(i * 2U) + 1U] = src[0];
    }
    tx = s_swap_buf;
#endif

    esp_err_t err = ili9225_write_area((uint16_t)area->x1,
                                       (uint16_t)area->y1,
                                       (uint16_t)area->x2,
                                       (uint16_t)area->y2,
                                       tx,
                                       byte_count);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "ili9225_write_area failed (%s)", esp_err_to_name(err));
    }

    lv_disp_flush_ready(drv);
}

static esp_err_t init_runtime(void)
{
    ili9225_cfg_t cfg = {
        .host = SPI2_HOST,
        .pin_clk = SA_DISP_CLK_PIN,
        .pin_mosi = SA_DISP_SDA_PIN,
        .pin_dc = SA_DISP_RS_PIN,
        .pin_rst = SA_DISP_RST_PIN,
        .pin_cs = SA_DISP_CS_PIN,
        .clock_speed_hz = SA_DISP_SPI_HZ,
    };

    esp_err_t err = ili9225_init(&cfg);
    if (err != ESP_OK) {
        return err;
    }

    lv_init();

    s_buf1 = heap_caps_malloc(DISPLAY_BUF_PIXELS * sizeof(lv_color_t), MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
    s_buf2 = heap_caps_malloc(DISPLAY_BUF_PIXELS * sizeof(lv_color_t), MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
    s_swap_buf = heap_caps_malloc(DISPLAY_BUF_PIXELS * sizeof(lv_color_t), MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
    if (s_buf1 == NULL || s_buf2 == NULL || s_swap_buf == NULL) {
        return ESP_ERR_NO_MEM;
    }

    lv_disp_draw_buf_init(&s_draw_buf, s_buf1, s_buf2, DISPLAY_BUF_PIXELS);

    static lv_disp_drv_t disp_drv;
    lv_disp_drv_init(&disp_drv);
    /* With sw_rotate enabled, LVGL expects the driver to advertise the
     * panel's native resolution and handles the logical 220x176 landscape
     * view through rotation internally. */
    disp_drv.hor_res = DISPLAY_NATIVE_W;
    disp_drv.ver_res = DISPLAY_NATIVE_H;
    disp_drv.flush_cb = display_flush;
    disp_drv.draw_buf = &s_draw_buf;
    disp_drv.rotated = LV_DISP_ROT_90;
    disp_drv.sw_rotate = 1;
    lv_disp_drv_register(&disp_drv);

    const esp_timer_create_args_t timer_args = {
        .callback = lv_tick_cb,
        .name = "display_tick",
    };
    err = esp_timer_create(&timer_args, &s_tick_timer);
    if (err != ESP_OK) {
        return err;
    }
    err = esp_timer_start_periodic(s_tick_timer, DISPLAY_TICK_MS * 1000ULL);
    if (err != ESP_OK) {
        return err;
    }

#if SA_DISP_SELF_TEST
    run_self_test();
#endif
    build_screen();
    render_screen();
    s_ready = true;
    return ESP_OK;
}

static void display_task(void *arg)
{
    (void)arg;

    s_init_result = init_runtime();
    if (s_init_done != NULL) {
        xSemaphoreGive(s_init_done);
    }
    if (s_init_result != ESP_OK) {
        vTaskDelete(NULL);
    }

    TickType_t last_render = 0;
    while (true) {
        lv_timer_handler();

        TickType_t now = xTaskGetTickCount();
        if ((now - last_render) >= pdMS_TO_TICKS(DISPLAY_UI_REFRESH_MS)) {
            render_screen();
            last_render = now;
        }

        vTaskDelay(pdMS_TO_TICKS(DISPLAY_TASK_DELAY_MS));
    }
}

static TickType_t init_wait_ticks(void)
{
    uint32_t wait_ms = DISPLAY_INIT_WAIT_BASE_MS;

#if SA_DISP_SELF_TEST
    wait_ms += (SA_DISP_SELF_TEST_HOLD_MS * DISPLAY_SELF_TEST_SCREEN_COUNT);
#endif
    wait_ms += DISPLAY_INIT_WAIT_MARGIN_MS;

    return pdMS_TO_TICKS(wait_ms);
}

static void cleanup_failed_init(void)
{
    s_ready = false;

    if (s_tick_timer != NULL) {
        esp_timer_stop(s_tick_timer);
        esp_timer_delete(s_tick_timer);
        s_tick_timer = NULL;
    }

    if (s_buf1 != NULL) {
        free(s_buf1);
        s_buf1 = NULL;
    }
    if (s_buf2 != NULL) {
        free(s_buf2);
        s_buf2 = NULL;
    }
    if (s_swap_buf != NULL) {
        free(s_swap_buf);
        s_swap_buf = NULL;
    }
    if (s_init_done != NULL) {
        vSemaphoreDelete(s_init_done);
        s_init_done = NULL;
    }
    s_task = NULL;
}

#endif

esp_err_t display_service_init(void)
{
#if SA_ENABLE_ILI9225
    if (s_ready) {
        return ESP_OK;
    }
    if (s_task != NULL) {
        return s_init_result;
    }

    s_init_done = xSemaphoreCreateBinary();
    if (s_init_done == NULL) {
        cleanup_failed_init();
        return ESP_ERR_NO_MEM;
    }

    BaseType_t rc = xTaskCreatePinnedToCore(display_task,
                                            "display_service",
                                            8192,
                                            NULL,
                                            5,
                                            &s_task,
                                            tskNO_AFFINITY);
    if (rc != pdPASS) {
        cleanup_failed_init();
        return ESP_ERR_NO_MEM;
    }

    if (xSemaphoreTake(s_init_done, init_wait_ticks()) != pdTRUE) {
        cleanup_failed_init();
        return ESP_ERR_TIMEOUT;
    }
    vSemaphoreDelete(s_init_done);
    s_init_done = NULL;

    if (s_init_result != ESP_OK) {
        cleanup_failed_init();
        return s_init_result;
    }

    ESP_LOGI(TAG, "init OK");
    return ESP_OK;
#else
    return ESP_OK;
#endif
}

bool display_service_is_ready(void)
{
#if SA_ENABLE_ILI9225
    return s_ready;
#else
    return false;
#endif
}

void display_service_set_boot_phase(display_boot_phase_t phase)
{
#if SA_ENABLE_ILI9225
    portENTER_CRITICAL(&s_state_lock);
    s_state.phase = phase;
    portEXIT_CRITICAL(&s_state_lock);
#else
    (void)phase;
#endif
}

void display_service_set_mode(bool on)
{
#if SA_ENABLE_ILI9225
    portENTER_CRITICAL(&s_state_lock);
    s_state.mode_known = true;
    s_state.mode_on = on;
    portEXIT_CRITICAL(&s_state_lock);
#else
    (void)on;
#endif
}

void display_service_set_relay_states(const bool relay_states[3])
{
#if SA_ENABLE_ILI9225
    if (relay_states == NULL) {
        return;
    }

    portENTER_CRITICAL(&s_state_lock);
    for (size_t i = 0; i < DISPLAY_RELAY_COUNT; i++) {
        s_state.relay_states[i] = relay_states[i];
    }
    portEXIT_CRITICAL(&s_state_lock);
#else
    (void)relay_states;
#endif
}

void display_service_set_sensor_snapshot(const display_sensor_snapshot_t *snapshot)
{
#if SA_ENABLE_ILI9225
    if (snapshot == NULL) {
        return;
    }

    portENTER_CRITICAL(&s_state_lock);
    s_state.sensor = *snapshot;
    portEXIT_CRITICAL(&s_state_lock);
#else
    (void)snapshot;
#endif
}
