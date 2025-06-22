#!/bin/bash
# Push Notification (using Matrix)
#
# Script Name   : check_mk_matrix-notify.sh
# Description   : Send Checkmk notifications by Matrix
# Adapted from  : https://github.com/filipnet/checkmk-telegram-notify
# License       : BSD 3-Clause "New" or "Revised" License
# ======================================================================================

# --- Prefer values from Custom User Attributes or fallback parameters ---

# HOMESERVER
if [[ -n "${NOTIFY_CONTACT_MATRIX_HOMESERVER}" ]]; then
    HOMESERVER="${NOTIFY_CONTACT_MATRIX_HOMESERVER}"
    echo "DEBUG: HOMESERVER set from NOTIFY_CONTACT_MATRIX_HOMESERVER: ${HOMESERVER}" >&2
elif [[ -n "${NOTIFY_PARAMETER_1}" ]]; then
    HOMESERVER="${NOTIFY_PARAMETER_1}"
    echo "DEBUG: HOMESERVER set from NOTIFY_PARAMETER_1: ${HOMESERVER}" >&2
else
    echo "ERROR: No Matrix homeserver URL provided. Exiting" >&2
    exit 2
fi

# TOKEN
if [[ -n "${NOTIFY_CONTACT_MATRIX_API_TOKEN}" ]]; then
    TOKEN="${NOTIFY_CONTACT_MATRIX_API_TOKEN}"
    echo "DEBUG: TOKEN set from NOTIFY_CONTACT_MATRIX_API_TOKEN (hidden)" >&2
elif [[ -n "${NOTIFY_PARAMETER_2}" ]]; then
    TOKEN="${NOTIFY_PARAMETER_2}"
    echo "DEBUG: TOKEN set from NOTIFY_PARAMETER_2 (hidden)" >&2
else
    echo "ERROR: No Matrix access token provided. Exiting" >&2
    exit 2
fi

# ROOM_ID
if [[ -n "${NOTIFY_CONTACT_MATRIX_ROOM_ID}" ]]; then
    ROOM_ID="${NOTIFY_CONTACT_MATRIX_ROOM_ID}"
    echo "DEBUG: ROOM_ID set from NOTIFY_CONTACT_MATRIX_ROOM_ID: ${ROOM_ID}" >&2
elif [[ -n "${NOTIFY_PARAMETER_3}" ]]; then
    ROOM_ID="${NOTIFY_PARAMETER_3}"
    echo "DEBUG: ROOM_ID set from NOTIFY_PARAMETER_3: ${ROOM_ID}" >&2
else
    echo "ERROR: No Matrix Room ID provided. Exiting" >&2
    exit 2
fi

# Set an appropriate emoji for the current state
if [[ ${NOTIFY_WHAT} == "SERVICE" ]]; then
        STATE="${NOTIFY_SERVICESHORTSTATE}"
else
        STATE="${NOTIFY_HOSTSHORTSTATE}"
fi
case "${STATE}" in
    OK|UP)
        EMOJI=$'\xE2\x9C\x85'
        ;;
    WARN)
        EMOJI=$'\xE2\x9A\xA0'
        ;;
    CRIT|DOWN)
        EMOJI=$'\xF0\x9F\x86\x98'
        ;;
    UNKN)
        EMOJI=$'\xF0\x9F\x94\x84'
        ;;
esac
EMOJI+=$'\xEF\xB8\x8F'

# Create a MESSAGE variable
MESSAGE="${NOTIFY_HOSTNAME} (${NOTIFY_HOSTALIAS})\n"
MESSAGE+="${EMOJI} ${NOTIFY_WHAT} ${NOTIFY_NOTIFICATIONTYPE}\n\n"
if [[ ${NOTIFY_WHAT} == "SERVICE" ]]; then
        MESSAGE+="${NOTIFY_SERVICEDESC}\n"
        MESSAGE+="State changed from ${NOTIFY_PREVIOUSSERVICEHARDSHORTSTATE} to ${NOTIFY_SERVICESHORTSTATE}\n"
        MESSAGE+="${NOTIFY_SERVICEOUTPUT}\n"
else
        MESSAGE+="State changed from ${NOTIFY_PREVIOUSHOSTHARDSHORTSTATE} to ${NOTIFY_HOSTSHORTSTATE}\n"
        MESSAGE+="${NOTIFY_HOSTOUTPUT}\n"
fi
MESSAGE+="\nIPv4: ${NOTIFY_HOST_ADDRESS_4} \nIPv6: ${NOTIFY_HOST_ADDRESS_6}\n"
MESSAGE+="${NOTIFY_SHORTDATETIME} | ${OMD_SITE}"

# Generate transaction ID
TXN_ID=$(uuidgen)

# Send message to Matrix room
response=$(curl -s -X PUT "${HOMESERVER}/_matrix/client/v3/rooms/${ROOM_ID}/send/m.room.message/${TXN_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
        \"msgtype\": \"m.text\",
        \"body\": \"${MESSAGE}\"
      }")

if [ $? -ne 0 ]; then
        echo "Not able to send Matrix message" >&2
        echo $response >&2
        exit 2
else
        echo "Matrix message sent successfully" >&2
        exit 0
fi
