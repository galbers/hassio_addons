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
# Temporarily disabled to debug device detection issues
# set -e

export LANG=C
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export LD_LIBRARY_PATH=/usr/local/lib64

# Function to list all RTL-SDR devices for debugging
list_rtl_devices() {
    bashio::log.info "=== Available RTL-SDR Devices ==="
    local rtl_output
    rtl_output=$(rtl_sdr -d 9999 2>&1)
    echo "$rtl_output" | while IFS= read -r line; do
        bashio::log.info "$line"
    done
    bashio::log.info "================================="
}

# Function to find device index by serial number
find_device_index() {
    local serial_num="$1"
    local device_index=""
    
    bashio::log.info "=== DEBUG: Device Detection Process ==="
    bashio::log.info "Looking for device with serial number: '$serial_num'"
    
    # Get raw rtl_sdr output for debugging
    local rtl_output
    rtl_output=$(rtl_sdr -d 9999 2>&1)
    bashio::log.info "Raw rtl_sdr output received, processing..."
    
    # Show all lines containing SN for debugging
    bashio::log.info "All lines containing 'SN:':"
    echo "$rtl_output" | grep "SN:" | while IFS= read -r line; do
        bashio::log.info "  $line"
    done
    
    # Simple method - find the line with our serial number and extract the device index
    bashio::log.info "Searching for serial number '$serial_num'..."
    local matching_line
    matching_line=$(echo "$rtl_output" | grep "SN: $serial_num")
    bashio::log.info "Matching line: '$matching_line'"
    
    if [ -n "$matching_line" ]; then
        # Extract the device index from the beginning of the line
        # Format: "  1:  Nooelec, RTL2838UHIDIR, SN: 433"
        device_index=$(echo "$matching_line" | sed 's/^[[:space:]]*\([0-9]\+\):.*/\1/')
        bashio::log.info "Extracted device index: '$device_index'"
    else
        bashio::log.info "No matching line found for serial number '$serial_num'"
    fi
    
    bashio::log.info "=== END DEBUG: Device Detection Process ==="
    echo "$device_index"
}

# Start the listener and enter an endless loop
bashio::log.blue "::::::::Starting RTL_433 with parameters::::::::"
bashio::log.info "Addon Version: $(bashio::addon.version)"
bashio::log.info "Script Updated: 2025-08-22 with improved device detection"
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
bashio::log.info "About to call find_device_index function..."
DEVICE_INDEX=$(find_device_index "$RTL_SDR_SERIAL_NUM")
bashio::log.info "find_device_index function returned: '$DEVICE_INDEX'"

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
