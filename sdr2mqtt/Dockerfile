ARG BUILD_FROM
FROM $BUILD_FROM

# Define environment variables
# Use this variable when creating a container to specify the MQTT broker host.
ENV MQTT_HOST=127.0.0.1 \
    MQTT_PORT=1883 \
    MQTT_USERNAME="" \
    MQTT_PASSWORD="" \
    MQTT_RETAIN=True \
    MQTT_TOPIC=rtl_433 \
    FREQUENCY=433.92M \
    PROTOCOL="" \
    RTL_SDR_SERIAL_NUM=433 \
    WHITELIST_ENABLE=False \
    EXPIRE_AFTER=0 \
    WHITELIST="" \
    DISCOVERY_PREFIX=homeassistant \
    DISCOVERY_INTERVAL=600 \
    AUTO_DISCOVERY=False \
    DEBUG=False \
    LANG=C.UTF-8

LABEL Maintainer="Jeffrey Stone" \
Description="This image is used to start the RTL433 to HASS script that will monitor for 433Mhz devices and send the data to an MQTT server"

WORKDIR /data

# Copy scripts
COPY entry.sh rtl_433_mqtt_hass.py /scripts/
# install rtl_433, rtl-sdr, libusb, mosquitto-clients, python3 py3-paho-mqtt; and deps of rtl_433_mqtt_hass.py.
# make entry.sh and rtl_433_mqtt_hass.py executable.
RUN apk add --no-cache rtl-sdr rtl_433 libusb mosquitto-clients python3 py3-paho-mqtt sed && \
    chmod +x /scripts/entry.sh && \
    chmod +x /scripts/rtl_433_mqtt_hass.py

# Execute entry script
# ENTRYPOINT [ "/scripts/entry.sh" ]
# Shell form entry script
ENTRYPOINT [ "bash", "-c", "/scripts/entry.sh $(rtl_sdr -d 9999 |& grep 'SN: $RTL_SDR_SERIAL_NUM' |& grep -o '^[^:]*' | sed 's/^[ \t]*//;s/[ \t]*$//')" ].
