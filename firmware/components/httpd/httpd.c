/**
 * @file httpd.c
 *
 * @brief HTTP info server + mDNS advertisement.
 *
 * Architecture:
 *   - httpd_server_start() inits mDNS then starts the HTTP server.
 *   - GET /api/info — returns device_id, firmware version, current IP.
 *   - Only the info endpoint is served; handlers share a context struct
 *     (device_id, ip) passed via httpd_register_uri_handler user_ctx.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "httpd.h"

#include "config.h"
#include "esp_http_server.h"
#include "esp_log.h"

#include <string.h>

static const char *TAG = "httpd";

/* ── Handler context ─────────────────────────────────────────────────────── */

typedef struct {
    char device_id[64];
    char ip[16];
} httpd_ctx_t;

static httpd_ctx_t s_ctx;

/* ── GET /api/info ───────────────────────────────────────────────────────── */

static esp_err_t info_get_handler(httpd_req_t *req)
{
    httpd_ctx_t *ctx = (httpd_ctx_t *)req->user_ctx;

    char resp[256];
    snprintf(resp, sizeof(resp),
             "{\"device_id\":\"%s\",\"firmware\":\"%s\",\"ip\":\"%s\"}",
             ctx->device_id, FIRMWARE_VERSION, ctx->ip);

    httpd_resp_set_type(req, "application/json");
    httpd_resp_sendstr(req, resp);
    ESP_LOGI(TAG, "GET /api/info → %s", resp);
    return ESP_OK;
}

static const httpd_uri_t uri_info = {
    .uri      = "/api/info",
    .method   = HTTP_GET,
    .handler  = info_get_handler,
    .user_ctx = &s_ctx,
};

/* ── Public API ──────────────────────────────────────────────────────────── */

esp_err_t httpd_server_start(const char *device_id, const char *ip)
{
    /* Store context for URI handlers */
    strlcpy(s_ctx.device_id, device_id != NULL ? device_id : "", sizeof(s_ctx.device_id));
    strlcpy(s_ctx.ip, ip != NULL ? ip : "", sizeof(s_ctx.ip));

    /* HTTP server */
    httpd_handle_t server = NULL;
    httpd_config_t cfg = HTTPD_DEFAULT_CONFIG();
    cfg.server_port = CONFIG_SA_HTTPD_PORT;

    esp_err_t err = httpd_start(&server, &cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "httpd_start failed (%s)", esp_err_to_name(err));
        return err;
    }

    httpd_register_uri_handler(server, &uri_info);

    ESP_LOGI(TAG, "HTTP server started on port %d (device: %s)", CONFIG_SA_HTTPD_PORT, device_id);
    return ESP_OK;
}
