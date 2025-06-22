# HELP & TROUBLESHOOTING GUIDE

Having trouble getting Checkmk Matrix notifications to work? This guide will help you identify and resolve common issues.

<!-- TOC -->

- [HELP & TROUBLESHOOTING GUIDE](#help--troubleshooting-guide)
  - [QUICK CHECKLIST](#quick-checklist)
  - [LOGFILE ANALYSIS](#logfile-analysis)
  - [VALIDATE NOTIFICATION (DRY-RUN)](#validate-notification-dry-run)
  - [Why Messages Are Not End-to-End Encrypted](#why-messages-are-not-end-to-end-encrypted)
  - [Why use PUT instead of plain GET or POST?](#why-use-put-instead-of-plain-get-or-post)
  - [ERROR CASE: BOT NOT IN ROOM](#error-case-bot-not-in-room)
  - [ERROR CASE: NO MATRIX HOMESERVER URL PROVIDED (OR SIMILAR)](#error-case-no-matrix-homeserver-url-provided-or-similar)
  - [REFERENCES AND DOCUMENTATION](#references-and-documentation)

<!-- /TOC -->

## QUICK CHECKLIST

Before diving into advanced troubleshooting, ensure you have checked the following:

- **curl** is installed on your system.
  - Run `curl --version` to verify.
- **Homeserver URL**, **Matrix access token** and **room ID** are correct.
  - Avoid extra spaces, line breaks, or incorrect quotes in your configuration.
- The **bot user is invited to the Matrix room** and has permission to post.
  - Test posting with `curl` to confirm the issue is not with the Checkmk script.
- Your Checkmk host or Docker container has **internet access**.
  - Test with `curl` to the Matrix homeserver API.
  - Watch for errors like `no route to host` (firewall/proxy issues).
- The **notification script is executable**.
  - Run: `chmod +x check_mk_matrix-notify.sh`
- You have followed the steps in the [README instructions](./README.md#check_mk-configuration).

## LOGFILE ANALYSIS

Check the Checkmk notification log for error messages. Replace `{sitename}` with your actual site name:

```bash
tail -f /omd/sites/{sitename}/var/log/notify.log
```

## VALIDATE NOTIFICATION (DRY-RUN)

To verify your Matrix bot can send messages independently of Checkmk, use this direct API call:

```bash
curl -X POST 'https://matrix.example.org/_matrix/client/r0/rooms/<ROOM_ID>:matrix.example.org/send/m.room.message' \
  -H 'Authorization: Bearer <ACCESS_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{
        "msgtype":"m.text",
        "body":"Test message from Checkmk bot"
      }'
```

- Replace `<ROOM_ID>` and `<ACCESS_TOKEN>` with your actual values.
- Adjust the homeserver URL (`matrix.example.org`) as needed.

Other option: Manual execution from shell

```bash
export NOTIFY_CONTACT_MATRIX_HOMESERVER="https://matrix.example.org"
export NOTIFY_CONTACT_MATRIX_TOKEN="syt_xxx"
export NOTIFY_CONTACT_MATRIX_ROOMID="!abcdefg:example.org"
export NOTIFY_CONTACT_SHORTTEXT="Manual Matrix test"
export NOTIFY_CONTACT_LONGTEXT="Checkmk simulated message."

/omd/sites/<site>/local/share/check_mk/notifications/check_mk_matrix-notify.sh
```

This test confirms:

- Access token and room ID are valid
- Bot user has permission to post
- Host/container has internet access
- A JSON response with an event ID means the message was sent

## Why Messages Are Not End-to-End Encrypted

This project sends messages to Matrix rooms using the [Matrix Client-Server API](https://spec.matrix.org/latest/client-server-api/).  
**Messages are not end-to-end encrypted (E2EE)** – for good technical reasons:

| Method                         | End-to-End Encryption | Transport Encryption (TLS) | API Compatible    | Implementation Complexity |
| ------------------------------ | --------------------- | -------------------------- | ----------------- | ------------------------- |
| This implementation (API only) | ❌ No                 | ✅ Yes                     | ✅ Yes            | 🔽 Low                    |
| Full-featured Matrix clients   | ✅ Yes                | ✅ Yes                     | ❌ No (needs SDK) | 🔼 High                   |

Matrix E2EE (via `m.room.encrypted` events) requires full cryptographic session handling with **Olm/Megolm**, device keys, key exchanges, and ratchets – none of which can be implemented securely with simple REST API calls.

**However**, this project does transmit all messages over a **secure TLS connection**, meaning that:

- Messages are encrypted **in transit**
- No plaintext content is exposed over the network
- Transport-level confidentiality and integrity are guaranteed

> ⚠️ Only end-to-end encryption (E2EE) would prevent the homeserver from accessing message content. This project does not provide that level of protection by design.

## Why use PUT instead of plain GET or POST?

The Matrix API uses a unique txn_id for every message sent with PUT. This design ensures idempotency: if the request is retried (e.g., due to network issues), the server recognizes the txn_id and doesn’t create a duplicate message. This allows for safe “pull-style” retries and guarantees that each message is stored only once, regardless of how many times the request is attempted.

## ERROR CASE: BOT NOT IN ROOM

**Error message:**

```
{"errcode":"M_FORBIDDEN","error":"User @bot-checkmk:matrix.example.org not in room !anonymizedRoomId:matrix.example.org"}
```

**Cause:**  
The bot user is not a member of the target Matrix room.

**Solution:**

- Invite the bot user (e.g., `@bot-checkmk:matrix.example.org`) to the room (`!anonymizedRoomId:matrix.example.org`) using your Matrix client.
- Make sure the bot user accepts the invitation and joins the room.
- You can use the [Element Web client](https://app.element.io) to manage room invitations and membership online.
- Retry sending the notification.

## ERROR CASE: NO MATRIX HOMESERVER URL PROVIDED (OR SIMILAR)

**Error message:**

```bash
2025-06-17 22:01:00,395 [20] [cmk.base.notify]      Output: No Matrix homeserver URL provided. Exiting
2025-06-17 22:01:00,395 [20] [cmk.base.notify]      Plug-in exited with code 2
```

**Cause:**  
The script was executed without a valid Matrix homeserver URL. This typically means that the required custom user attribute was not set or was left empty. The script checks for this parameter before continuing and exits early if it’s missing.

**Solution:**
In Checkmk, open the Edit Notification Rule or the Edit User dialog (depending on your setup), and ensure that the field for the Matrix homeserver is filled in with a proper URL

## REFERENCES AND DOCUMENTATION

For more troubleshooting and examples, see:

- [Checkmk Documentation: Notifications – Chapter 11.3](https://docs.checkmk.com/latest/en/notifications.html)
- [Checkmk GitHub Repository](https://github.com/Checkmk/checkmk)
- [Checkmk Forum](https://forum.checkmk.com/)
- [Matrix Client-Server API](https://spec.matrix.org/latest/client-server-api/)
- [Matrix Bot SDK Documentation](https://turt2live.github.io/matrix-bot-sdk/tutorial-bot.html)
