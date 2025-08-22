#!/usr/bin/bashio
CONFIG_PATH=/data/options.json

MQTT_HOST="$(bashio::config 'mqtt_host')"
MQTT_PORT="$(bashio::config 'mqtt_port')"
MQTT_USERNAME="$(bashio::config 'mqtt_user')"
MQTT_PASSWORD="$(bashio::config 'mqtt_password')"
MQTT_TOPIC="$(bashio::config 'mqtt_topic')"
MQTT_RETAIN="$(bashio::config 'mqtt_retain')"
RTL_SDR_SERIAL_NUM="$(bashio::config 'rtl_sdr_serial_num')"
PROTOCOL="$(bashio::config 'protocol')"
FREQUENCY="$(bashio::config 'frequency')"
UNITS="$(bashio::config 'units')"
DISCOVERY_PREFIX="$(bashio::config 'discovery_prefix')"
DISCOVERY_INTERVAL="$(bashio::config 'discovery_interval')"
WHITELIST_ENABLE="$(bashio::config 'whitelist_enable')"
WHITELIST="$(bashio::config 'whitelist')"
AUTO_DISCOVERY="$(bashio::config 'auto_discovery')"
DEBUG="$(bashio::config 'debug')"
EXPIRE_AFTER="$(bashio::config 'expire_after')"

# Exit immediately if a command exits with a non-zero status:
set -e

export LANG=C
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export LD_LIBRARY_PATH=/usr/local/lib64

# Function to list all RTL-SDR devices for debugging
list_rtl_devices() {
    bashio::log.info "=== Available RTL-SDR Devices ==="
    rtl_sdr -d 9999 2>&1 | while IFS= read -r line; do
        bashio::log.info "$line"
    done
    bashio::log.info "================================="
}

# Function to find device index by serial number
find_device_index() {
    local serial_num="$1"
    local device_index
    
    # Primary detection method
    device_index=$(rtl_sdr -d 9999 2>&1 | grep -E "^[0-9]+:" | grep "SN: $serial_num" | cut -d: -f1 | head -1)
    
    # Alternative method - sometimes the format is different
    if [ -z "$device_index" ]; then
        device_index=$(rtl_sdr -d 9999 2>&1 | grep -B1 "SN: $serial_num" | grep -E "^[0-9]+:" | cut -d: -f1 | head -1)
    fi
    
    # Third method - try case insensitive match
    if [ -z "$device_index" ]; then
        device_index=$(rtl_sdr -d 9999 2>&1 | grep -iE "^[0-9]+:" | grep -i "SN: $serial_num" | cut -d: -f1 | head -1)
    fi
    
    echo "$device_index"
}

# Start the listener and enter an endless loop
bashio::log.blue "::::::::Starting RTL_433 with parameters::::::::"
bashio::log.info "MQTT Host =" $MQTT_HOST
bashio::log.info "MQTT port =" $MQTT_PORT
bashio::log.info "MQTT User =" $MQTT_USERNAME
bashio::log.info "MQTT Password =" $(echo $MQTT_PASSWORD | sha256sum | cut -f1 -d' ')
bashio::log.info "MQTT Topic =" $MQTT_TOPIC
bashio::log.info "MQTT Retain =" $MQTT_RETAIN
bashio::log.info "RTL-SDR Device Serial Number =" $RTL_SDR_SERIAL_NUM
bashio::log.info "PROTOCOL =" $PROTOCOL
bashio::log.info "FREQUENCY =" $FREQUENCY
bashio::log.info "Whitelist Enabled =" $WHITELIST_ENABLE
bashio::log.info "Whitelist =" $WHITELIST
bashio::log.info "Expire After =" $EXPIRE_AFTER
bashio::log.info "UNITS =" $UNITS
bashio::log.info "DISCOVERY_PREFIX =" $DISCOVERY_PREFIX
bashio::log.info "DISCOVERY_INTERVAL =" $DISCOVERY_INTERVAL
bashio::log.info "AUTO_DISCOVERY =" $AUTO_DISCOVERY
bashio::log.info "DEBUG =" $DEBUG

# List all available devices for debugging
list_rtl_devices

# Find the device index for the specified serial number
DEVICE_INDEX=$(find_device_index "$RTL_SDR_SERIAL_NUM")

# Validate device detection
if [ -z "$DEVICE_INDEX" ]; then
    bashio::log.error "No RTL-SDR device found with serial number: $RTL_SDR_SERIAL_NUM"
    bashio::log.error "Please check your device configuration and ensure the device is connected."
    bashio::log.error "Available devices are listed above."
    exit 1
else
    bashio::log.info "RTL-SDR Device Index = $DEVICE_INDEX"
    bashio::log.blue "Using RTL-SDR Device with serial number \"$RTL_SDR_SERIAL_NUM\" at index $DEVICE_INDEX"
fi

bashio::log.blue "::::::::rtl_433 running output::::::::"

# Run rtl_433 with the validated device index
bashio::log.info "Executing: rtl_433 $FREQUENCY $PROTOCOL -C $UNITS -F mqtt://$MQTT_HOST:$MQTT_PORT,user=$MQTT_USERNAME,pass=***,retain=$MQTT_RETAIN,events=$MQTT_TOPIC/events,states=$MQTT_TOPIC/states,devices=$MQTT_TOPIC[/model][/id][/channel:A] -M time:tz:local -M protocol -M level -d $DEVICE_INDEX"

rtl_433 $FREQUENCY $PROTOCOL -C $UNITS -F mqtt://$MQTT_HOST:$MQTT_PORT,user=$MQTT_USERNAME,pass=$MQTT_PASSWORD,retain=$MQTT_RETAIN,events=$MQTT_TOPIC/events,states=$MQTT_TOPIC/states,devices=$MQTT_TOPIC[/model][/id][/channel:A] -M time:tz:local -M protocol -M level -d $DEVICE_INDEX | /scripts/rtl_433_mqtt_hass.py
