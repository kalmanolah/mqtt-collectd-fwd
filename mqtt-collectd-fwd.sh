#!/bin/bash

SERVICE_NAME="mqtt-collectd-fwd"
CONFIGURATION_PATH="/usr/local/etc/${SERVICE_NAME}.cfg"

# if [ ! -f "$CONFIGURATION_PATH" ]; then
#     echo "configuration not found at ${CONFIGURATION_PATH}"
#     exit 1
# fi

# Change working directory to script directory
# cd "$(dirname "$0")"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# Include configuration
. $CONFIGURATION_PATH

# Set default values for configuration
: ${MQTT_HOST:='127.0.0.1'}
: ${MQTT_PORT:='1883'}
: ${MQTT_USER:=''}
: ${MQTT_PASSWORD:=''}
: ${MQTT_TOPIC:='#'}

: ${COLLECTD_HOST:='127.0.0.1'}
: ${COLLECTD_PORT:='25826'}

# Example topic format: /foo/<host>/bar/<plugin>/<type>
: ${HOST_REGEX:='/[^/]+/([^/]+)/.*'}
: ${PLUGIN_REGEX:='/[^/]+/[^/]+/[^/]+/([^/]+)/.*'}
: ${TYPE_REGEX:='/[^/]+/[^/]+/[^/]+/[^/]+/([^/]+).*'}

# Detect required binaries
MOSQUITTO_SUB_PATH=$(which mosquitto_sub)
NETCAT_PATH=$(which netcat)

if [[ -z "$MOSQUITTO_SUB_PATH" ]]; then
    echo "mosquitto_sub not found"
    exit 1
fi

if [[ -z "$NETCAT_PATH" ]]; then
    echo "netcat not found"
    exit 1
fi

while read -r line
do
    # Split topic and value
    PARTS=($line)
    TOPIC=${PARTS[0]}
    PARTS=("${PARTS[@]:1}")
    PAYLOAD="${PARTS[*]}"

    HOST='unknown'
    PLUGIN='unknown'
    TYPE='unknown'

    # Attempt to extract host, plugin, type from topic
    if [[ "$TOPIC" =~ $HOST_REGEX ]]; then
        HOST="${BASH_REMATCH[1]}"
    fi
    if [[ "$TOPIC" =~ $PLUGIN_REGEX ]]; then
        PLUGIN="${BASH_REMATCH[1]}"
    fi
    if [[ "$TOPIC" =~ $TYPE_REGEX ]]; then
        TYPE="${BASH_REMATCH[1]}"
    fi

    # Collectd expects values to begin with "(unix_timestamp|N):"
    # If our value doesn't start with "N:", make it so
    if [ "${PAYLOAD:0:2}" != "N:" ]; then
        PAYLOAD="N:${PAYLOAD}"
    fi

    # Forward data
    echo "PUTVAL \"${HOST}/${PLUGIN}/${TYPE}\" \"${PAYLOAD}\""
done < <(${MOSQUITTO_SUB_PATH} -h "${MQTT_HOST}" -p "${MQTT_PORT}" -u "${MQTT_USER}" -P "${MQTT_PASSWORD}" -t "${MQTT_TOPIC}" -v)
