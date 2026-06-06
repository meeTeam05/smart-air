# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Features

- **docs:** Enhance README with detailed features and app capabilities

### Documentation

- Update hero.png and add list LGVL in readme

## [0.1.3] - 2026-06-05

### Features

- **scripts:** Add telemetry csv export
- **ota:** Add app-driven version selection flow
- **settings:** Enhance device settings UI with updated calibration messages and navigation
- **data:** Add csv for mlai
- **firmware:** Integrate ILI9225 LVGL display subsystem
- **firmware:** Add relay gpio blink tool
- **firmware:** Render full display dashboard
- **data:** Append telemetry flat samples
- **firmware:** Show company logo on boot splash
- **data:** Refresh telemetry flat samples
- **firmware:** Preserve gas calibration across reset
- **app:** Improve BLE scan preflight handling
- Add Makefile and usage instructions in runbook
- **calibration:** Update calibration timeout and add test for confirmation duration
- **hardware:** Add Smart-Air PCB design files
- **config:** Add WebSocket buffer size and dynamic buffer configuration
- **docs:** Add runtime and configuration GIFs to README
- **docs:** Add app demo GIFs to README

### Bug Fixes

- **server:** Align ota hash with esp image digest
- **i2c:** Update SDA and SCL pin definitions for I2C scanner
- **app:** Refresh devices after realtime reset and app resume
- **app:** Clarify dashboard presence labels
- **firmware:** Update buzzer GPIO default
- **firmware:** Refine display dashboard rendering
- **firmware:** Apply local timezone to display clock
- **firmware:** Use timezone config wrapper

### Refactor

- **api:** Centralize runtime configuration
- **display_service:** Clean up formatting and improve readability of display configuration

### Miscellaneous

- Remove outdated implementation notes
- **tooling:** Refresh repo agent metadata
- **beads:** Export issue status interactions
- **tooling:** Refresh gitnexus metadata counts
- **tooling:** Refresh gitnexus metadata counts
- **tooling:** Refresh gitnexus metadata counts
- **tooling:** Refresh gitnexus metadata counts
- **tooling:** Refresh gitnexus metadata counts
- **server:** Remove Grafana service
- **tooling:** Refresh gitnexus metadata counts

## [0.1.2] - 2026-05-25

### Features

- **hooks:** Enhance session management and planning context handling
- **app:** Centralize provisioning defaults
- Add Cloudflare DDNS update script
- **firmware:** Add boot-time SNTP clock sync
- **codex:** Add bead into codex
- **firmware:** Sync shadow desired state
- **app:** Add notifications feed
- **server:** Add notifications feed

### Bug Fixes

- **firmware:** Address audit findings through high-8
- **codex:** Minimal coding agents
- **docker-compose:** Remove unnecessary restart policy from services
- **server:** Guard device announce polling by ownership
- **server:** Redact device secrets and cookie headers
- **server:** Reject wildcard cors origins in production
- **server:** Sanitize emqx api error messages
- **server:** Avoid refresh self-revocation race
- **server:** Commit command dispatch before publish
- **server:** Dedupe qos1 telemetry redelivery
- **server:** Ignore stale shadow reports
- **server:** Dedupe replayable realtime events
- **server:** Version shadow cache writes
- **server:** Normalize telemetry against db clock
- **server:** Avoid advisory lock hash collisions
- **server:** Reconnect realtime listener after db drops
- **server:** Add api retention cleanup job
- **server:** Cap realtime client connections
- **server:** Return created_at on device updates
- **server:** Validate shadow reserved keys first
- **server:** Prevent overlapping job sweeps
- **server:** Run command timeout sweep on startup
- **server:** Include emqx in readiness checks
- **server:** Add nginx api rate limits
- **server:** Add hsts headers
- **server:** Use fastify logger for emqx cleanup failures
- **codex:** Update skill for agents
- **server:** Enable nginx keepalive for api proxy
- **server:** Make member invites idempotent
- **server:** Add request ids to emqx api calls
- **server:** Stabilize device list pagination
- **server:** Harden auth input and token expiry
- **server:** Tighten health and mqtt readiness
- **server:** Make device provisioning and cleanup durable
- **server:** Harden command dispatch timing and bounds
- **server:** Harden shadow cache consistency
- **server:** Catch scheduler job rejections
- **server:** Protect logs and realtime capacity
- **server:** Reject polluted numeric query params
- **server:** Pin fast-uri dependency
- **firmware:** Preserve wifi credentials on connect failure
- **firmware:** Keep relay state on mqtt publish failure
- **firmware:** Guard task publishes during factory reset
- **firmware:** Cap repeated boot-error restarts
- **firmware:** Guard wifi event group lifetime
- **firmware:** Serialize wifi reconnect counter
- **firmware:** Guard mqtt client lifetime
- **firmware:** Guard gas calibration state
- **firmware:** Guard provisioning stop race
- **firmware:** Preserve mode state on publish failure
- **firmware:** Seed clock from rtc
- **firmware:** Reject invalid gas calibration samples
- **firmware:** Start local api before sntp sync
- **firmware:** Reject oversized ota urls
- **firmware:** Serialize buzzer access
- **firmware:** Make buzzer beeps asynchronous
- **firmware:** Validate sensor readings before publish
- **firmware:** Fail uncalibrated gas reads
- **firmware:** Use log interpolation for no2 curve
- **firmware:** Clean up led init failures
- **firmware:** Lock shared wifi ip buffer
- **firmware:** Retry failed mqtt subscriptions
- **firmware:** Guard config reads during reset
- **firmware:** Use correct sensor task critical API
- **firmware:** Log ota progress publish failures
- **firmware:** Stop timed out wifi connects
- **firmware:** Clean up failed wifi init
- **firmware:** Assemble fragmented mqtt payloads
- **firmware:** Update NO2 concentration curve for improved accuracy
- **app:** Guard wifi setup status updates after async steps
- **server:** Restrict desired shadow to supported keys
- **server:** Remove duplicate shadow sync on reconnect
- **app:** Cancel BLE provisioning notify listener
- **firmware:** Dedupe repeated mqtt commands
- **app:** Surface dashboard loading and error states
- **app:** Rebuild theme from notifier state
- **app:** Validate endpoint env values at startup
- **app:** Show settings room loading state
- **app:** Guard malformed realtime timestamps
- **app:** Ignore malformed telemetry timestamps
- **app:** Clear corrupt stored user session
- **app:** Guard malformed auth refresh payloads
- **app:** Validate auth service response bodies
- **app:** Validate home service response bodies
- **app:** Validate device service response bodies
- **server:** Clamp future shadow report ts
- **app:** Remove dead ble adapter cleanup
- **server:** Persist firmware version from status
- **server:** Reject impossible desired shadow relay state
- **app:** Cancel realtime reconnect backoff
- **app:** Use typed wifi setup timeout error
- **firmware:** Republish relay shadow on reconnect
- **app:** Tighten ble provisioning name match
- **app:** Guard malformed provisioning routes
- **firmware:** Cap inbound MQTT payloads
- **firmware:** Clean up wifi init failure path
- **firmware:** Propagate mqtt startup failures
- **firmware:** Bound provisioning recv timeouts
- **firmware:** Report provisioning recv failures
- **firmware:** Tolerate wifi teardown edge states
- **firmware:** Clean up failed calibration task start
- **.gitignore:** Reorganize entries and maintain consistency
- **httpd:** Handle errors during URI handler registration
- **app:** Treat queued dashboard commands as pending
- **app:** Preserve distinct same-second telemetry points
- **app:** Sync device summaries from shadow updates
- **firmware:** Clarify empty shadow delta log
- **server:** Avoid poisoning mqtt ack loop on shadow sync
- **server:** Cast telemetry timestamps before persistence
- **app:** Show dashboard sensor values with two decimals
- **app:** Prevent sensor tile overflow on large values
- **app:** Drive dashboard controls from realtime updates
- **app:** Restore safe back navigation

### Other

- Move calibration off MQTT callback
- Log sensor task JSON build failures
- Retry telemetry after publish failures
- Log sensor task stack watermark
- Reject mismatched i2c bus reuse
- Clean up adc bus init failures
- Harden no2 calibration quality
- Harden co calibration quality
- Serialize sht3x measurement state
- Keep ds3231 timestamps in utc
- Move led writes off timer task
- Unregister wifi event handlers
- Harden ble provisioning startup
- Roll back relay side effects on failure
- Split sysload boot stages
- Name boot timing and task settings
- Clarify public header docs
- Fix co sensor calibration warning
- Validate ds3231 calendar dates
- Fix ds3231 yday leap-year handling
- Verify config reboot task startup
- Fail fast on mqtt command registration errors
- Log mqtt rx allocation failures
- Guard ota task startup
- Bound ota sha256 hex formatting
- Name legacy device id nvs key
- Enable freertos stack end watchpoint
- Bound i2c device mutex waits

### Refactor

- **firmware:** Align runtime config with SA defaults
- Sync coding style
- **server:** Share email validation helpers
- **server:** Centralize positive env parsing
- **app:** Remove automation shell feature
- **app:** Remove chart entry from device dashboard

### Documentation

- Add datasheets for sensor
- Add operational runbook for smart-air server stack
- **server:** Document reserved desired shadow keys
- **server:** Document telemetry range limits
- **server:** Document relay control endpoint
- **server:** Document device mode endpoint
- **server:** Document device list status fields
- **server:** Document updated API constraints
- **firmware:** Align mqtt status payload examples
- Cleanup docs
- **server:** Align provisioning announce timeout
- **server:** Align shadow and realtime contracts
- Add server architecture document
- Add app architecture document
- Refresh system architecture document
- Expand app server and firmware architecture docs
- Add troubleshooting steps for notification loading issues
- Update API reference for notifications feed and telemetry details
- Update MQTT protocol documentation for clarity and structure
- Update AGENTS.md and CLAUDE.md for clarity and GitNexus integration

### Performance

- **server:** Reuse mqtt payload byte lengths

### Styling

- **server:** Wrap long mqtt import
- **server:** Rename auth rate limit config

### Testing

- **server:** Cover device list pagination order

### Miscellaneous

- Remove outdated app runtime bug audit document
- **server:** Log scheduler sweep heartbeats
- **server:** Add pgadmin healthcheck
- **firmware:** Document local provisioning trust model
- **firmware:** Document BLE provisioning trust model
- **firmware:** Document secret storage assumptions
- **firmware:** Record sntp boot-delay tradeoff

## [0.1.1] - 2026-05-15

### Features

- Add git-cliff configuration for changelog generation
- Add initial configuration files for firmware components
- Add buzzer driver implementation files
- Add DNS server implementation and header files
- Add LED driver implementation files
- Add MQTT driver implementation files
- Add webserver component files including CMake, headers, HTML, CSS, JS, and source
- Add WiFi driver implementation files and header files
- Add I2C bus driver implementation files and headers
- Add DS3231 RTC driver implementation files and headers
- Add SHT3x temperature and humidity sensor driver implementation files and headers
- Add SPI bus driver implementation files and headers
- Add ST7789 display driver implementation files and headers
- Add XPT2046 touch controller driver implementation files and headers
- Add OTA component implementation files and headers
- Add sysload and system component implementation files
- Add initial firmware structure with CMakeLists, Kconfig, linker script, main file, and partitions
- Add .clang-format file for ESP-IDF / ESP32 firmware style
- Add server/ Docker stack — nginx, emqx, api, postgres, redis, grafana, pgadmin, portainer
- **server:** EMQX Phase 1.2 — TLS config, ACL, cert script
- **firmware:** Add core config, drivers, and BLE provisioning scaffold
- **app:** Add Flutter mobile app scaffold and BLE provisioning flow
- **hardware:** Add KiCad project and reusable hardware libraries
- **server:** Add initial database migration
- **config:** Add CA certificate for secure communication
- **sensor:** Add sensor_task for polling SHT3x and DS3231, publishing telemetry via MQTT
- **mqtt:** Migrate MQTT client to sa_mqtt component with TLS support
- **httpd:** Implement HTTP API server with GET /api/info and POST /api/config endpoints
- **ota:** Implement HTTPS OTA firmware update with progress reporting and rollback
- **config:** Update LED GPIO pin for ESP32-S3-DevKitC-1 and add HTTP server port configuration
- **plugins:** Add authentication, database, MQTT, and Redis plugins
- **routes:** Add authentication, device commands, telemetry, and health check endpoints
- **commands:** Implement sendCommand and flushPending functions for command handling
- **api:** Initialize Fastify server with core plugins and routes
- **nginx:** Add HTTPS server configuration for OTA firmware and health check
- **ota-files:** Add .gitkeep to ensure directory persistence
- **env:** Update .env.example with API service configurations and EMQX MQTT credentials
- **docker:** Update docker-compose.yml for service configurations and volume mappings
- **gitignore:** Add entries for private notes and server secrets
- **docker-compose:** Update EMQX service volumes to use named volumes for data persistence
- **emqx:** Enable Plain MQTT listener on port 1883 and configure binding
- **api:** Normalize device IDs across routes and services
- **db:** Change device ID type from UUID to TEXT and update related constraints
- **api:** Update API service to include database volume and run migrations on startup
- **tests:** Add comprehensive test script for API interactions and device management
- **scripts:** Add various database interaction scripts for device management
- **mqtt:** Add response topic and handle command acknowledgment in MQTT event
- **core:** Implement API client, authentication interceptor, secure storage, and routing
- **auth:** Include refreshToken in response for mobile clients and update refresh token retrieval logic
- **security:** Add network security configuration to allow cleartext HTTP for local IPs
- **interceptor:** Enhance error handling to skip refresh on auth endpoints
- **command:** Add Command model with JSON serialization support
- **device:** Add Device and DeviceShadow models with JSON serialization
- **models:** Add Home and Room models with JSON serialization support
- **telemetry:** Add TelemetryPoint model with JSON serialization support
- **user:** Add User model with JSON serialization support
- **auth:** Implement AuthNotifier with login, register, and logout functionality
- **devices:** Implement DevicesNotifier and related providers for device management
- **homes:** Implement HomesNotifier and RoomsNotifier for home and room management
- **auth:** Implement Login and Register screens with form validation and error handling
- **devices:** Add CommandHistoryScreen, DeviceChartScreen, and DeviceDashboardScreen for device management and telemetry visualization
- **homes:** Add CreateHomeScreen, HomeDetailScreen, and HomesScreen for home management
- **profile:** Add ProfileScreen with user information and settings options
- **provision:** Add BleScanScreen and WifiSetupScreen for device provisioning
- **ble:** Update GATT UUIDs and enhance BLE service for provisioning
- **auth:** Implement authentication service with login, registration, and token refresh functionality
- **async:** Add AsyncValueWidget for handling asynchronous data states
- **main:** Refactor SmartAirApp to use ConsumerStatefulWidget and update theme change handling
- **storage:** Integrate flutter_secure_storage plugin across platforms
- **dependencies:** Update pubspec.yaml to include new packages for navigation, HTTP, and state management
- **devices:** Add provisioning poll endpoint to check device online status
- **sysload:** Add factory reset initialization and error handling
- **ble_prov:** Update GATT characteristics to allow write responses for SSID and Password
- **led:** Add factory reset state and update error state description
- **mqtt:** Add mqtt_stop function to safely stop and destroy the MQTT client
- **factory_reset:** Implement factory reset functionality with GPIO monitoring and reset sequence
- **factory_reset:** Add configuration options for factory reset button GPIO and hold duration
- **devices:** Validate home_id as a UUID in device provisioning
- **router:** Add route for creating a new home
- **auth:** Invalidate devices and homes providers on forced logout; optimize session restoration logic
- **devices:** Enhance device dashboard with time sync and removal options; improve data handling
- **ble_service:** Request larger MTU for JSON payloads; enhance sendCredentials method with timeout and error handling
- **sensor_task:** Include device timestamp in shadow report; increase shadow buffer size
- **sysload:** Add time sync callback for DS3231 and register with MQTT
- **ble_prov:** Include device MAC address in provisioning JSON response
- **mqtt:** Implement time synchronization callback for DS3231 RTC
- **device_chart:** Enhance telemetry data handling and improve x-axis intervals for chart display
- **dependencies:** Add google_fonts package version 6.3.3
- **theme:** Update color palette and enhance theme data for dark and light modes
- **theme:** Update color palette for dark and light modes and remove google_fonts dependency
- **firmware:** Add gas sensor telemetry and commands
- **server:** Harden MQTT and command handling
- **firmware:** Add demo-mode provisioning and typed MQTT control
- **app:** Overhaul mobile ui and device workflows
- **server:** Add API-owned realtime event pipeline
- **app:** Consume realtime API stream in device UI

### Bug Fixes

- **emqx:** Add required node block lost when mounting custom emqx.conf
- **emqx:** Remove mqtt.allow_anonymous — field removed in EMQX 5.x, auth chain enforces SEC-04
- **emqx:** Add dashboard HTTP listener — required explicit in EMQX 6.x
- **app:** Fix BLE provisioning UUID comparison using str128
- **profile:** Update active color property for notification switch
- **telemetry:** Correct aliasing in SQL queries for time bucket and payload extraction
- **cmake:** Correct component directory for MQTT and add factory reset component
- **gitignore:** Add firmware/managed_components to .gitignore
- **firmware:** Decouple device mode from relay flag

### Other

- Add api packaging and db migrations
- Harden auth and home validation
- Harden device lifecycle and mqtt runtime
- Harden command, shadow, and telemetry flows
- Replace legacy checks with runtime diagnostics
- Remove sisyphus opencode
- Delete CLAUDE.md and TODO.md files
- Reorganize core and general components
- Align provisioning and runtime config with server
- Replace shared defaults with explicit demo preset

### Refactor

- **docker-compose, nginx:** Clean up comments and formatting for clarity
- **mqtt:** Simplify status update logic and improve provisioning announcement handling
- **wifi_setup:** Streamline provisioning logic and remove unused components
- **firmware:** Clean code + OTA safety fixes + Cloudflare Tunnel setup
- **firmware:** Align drivers with current hardware topology

### Documentation

- Add .gitignore, LICENSE, and README documents
- Create CHANGELOG.md to document project updates
- Update section headers in README files to reflect correct context
- Add foundational documentation files for project structure and guidelines
- : add initial hardware documentation
- **architecture:** Expand system architecture and protocol docs
- **repo:** Refresh API and protocol references
- Refresh architecture and protocol references
- **repo:** Refresh architecture and repository docs

### Testing

- **widget:** Update smoke test to use SmartAirApp with ProviderScope
- Add 390dp counterpart verification suite

### Miscellaneous

- **repo:** Ignore local build and editor artifacts
- **app:** Point default API to public domain
- **hardware:** Sync KiCad schematics
- **repo:** Add codex workflow and repository guidance
- **server:** Align mqtt proxy and local tls config

<!-- generated by git-cliff -->
