cmake_minimum_required(VERSION 3.16)

set(EXTRA_COMPONENT_DIRS
    components/config
    components/core
    components/drivers/general/ble_prov
    components/drivers/general/wifi
    components/drivers/general/sa_mqtt
    components/drivers/general/led
    components/drivers/general/factory_reset
    components/drivers/general/buzzer
    components/drivers/general/dns
    components/drivers/i2c_bus
    components/drivers/i2c_devices/sht3x
    components/drivers/i2c_devices/ds3231
    components/drivers/spi_bus
    components/drivers/spi_devices/st7789
    components/drivers/spi_devices/xpt2046
    components/ota
)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(smart-air)
