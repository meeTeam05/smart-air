/**
 * @file httpd.c
 *
 * @brief HTTP API server + mDNS advertisement.
 *
 * Architecture:
 *   - httpd_server_start() inits mDNS then starts the HTTP server.
 *   - GET /api/info  — returns device_id, firmware version, current IP.
 *   - POST /api/config — validates Content-Type, rejects oversized body,
 *     parses JSON with cJSON, writes device_id + secret_key to NVS.
 *   - Both handlers share a context struct (device_id, ip) passed via
 *     httpd_register_uri_handler user_ctx.
 *
 * Copyright (C) 2026 MinhNhat & BaoViet
 */

#include "httpd.h"

#include "config.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "cJSON.h"
#include "sdkconfig.h"

#include <string.h>

static const char *TAG = "httpd";

#define BODY_MAX_LEN 512

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

/* ── POST /api/config ────────────────────────────────────────────────────── */

static esp_err_t config_post_handler(httpd_req_t *req)
{
    /* Validate Content-Type */
    char ct[64] = {0};
    if (httpd_req_get_hdr_value_str(req, "Content-Type", ct, sizeof(ct)) != ESP_OK
        || strstr(ct, "application/json") == NULL) {
        httpd_resp_set_status(req, "415 Unsupported Media Type");
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "{\"status\":\"error\",\"msg\":\"Content-Type must be application/json\"}");
        return ESP_OK;
    }

    /* Reject oversized body (SEC-01 style defense) */
    if (req->content_len > BODY_MAX_LEN) {
        httpd_resp_set_status(req, "413 Content Too Large");
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "{\"status\":\"error\",\"msg\":\"Request body too large\"}");
        return ESP_OK;
    }

    /* Read body */
    char body[BODY_MAX_LEN + 1] = {0};
    int received = httpd_req_recv(req, body, BODY_MAX_LEN);
    if (received <= 0) {
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "{\"status\":\"error\",\"msg\":\"Empty body\"}");
        return ESP_OK;
    }
    body[received] = '\0';

    /* Parse JSON */
    cJSON *root = cJSON_ParseWithLength(body, (size_t)received);
    if (root == NULL) {
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "{\"status\":\"error\",\"msg\":\"Invalid JSON\"}");
        return ESP_OK;
    }

    const cJSON *j_device_id  = cJSON_GetObjectItemCaseSensitive(root, "device_id");
    const cJSON *j_secret_key = cJSON_GetObjectItemCaseSensitive(root, "secret_key");

    if (!cJSON_IsString(j_device_id) || !cJSON_IsString(j_secret_key)) {
        cJSON_Delete(root);
        httpd_resp_set_status(req, "400 Bad Request");
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "{\"status\":\"error\",\"msg\":\"Missing device_id or secret_key\"}");
        return ESP_OK;
    }

    esp_err_t err = config_set_mqtt_creds(j_device_id->valuestring, j_secret_key->valuestring);
    cJSON_Delete(root);

    if (err != ESP_OK) {
        httpd_resp_set_status(req, "500 Internal Server Error");
        httpd_resp_set_type(req, "application/json");
        httpd_resp_sendstr(req, "{\"status\":\"error\",\"msg\":\"NVS write failed\"}");
        return ESP_OK;
    }

    httpd_resp_set_type(req, "application/json");
    httpd_resp_sendstr(req, "{\"status\":\"ok\"}");
    ESP_LOGI(TAG, "POST /api/config → credentials updated");
    return ESP_OK;
}

static const httpd_uri_t uri_config = {
    .uri      = "/api/config",
    .method   = HTTP_POST,
    .handler  = config_post_handler,
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
    httpd_register_uri_handler(server, &uri_config);

    ESP_LOGI(TAG, "HTTP server started on port %d (device: %s)", CONFIG_SA_HTTPD_PORT, device_id);
    return ESP_OK;
}
