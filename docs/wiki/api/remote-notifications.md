[Back to API](./index.md)

# Remote notifications

A desktop dotshell instance can pull notifications from another dotshell
machine over SSH. The destination replays each event through its own
notification server, so remote notifications use the normal popup, history,
and DND behavior.

Primary code: `modules/notifications/Manager.qml`

## Setup

Set **Settings → Notifications → Remote Notifications** to an SSH host alias,
or configure it from the destination machine's CLI:

```bash
dshell notifications remote set devserver
dshell notifications remote clear
```

Authentication, ports, and routing come from `~/.ssh/config`. Both machines
must run dotshell; the destination also needs `ssh`, `jq`, and `notify-send`.
Leaving the host blank keeps notifications local.

## Workflow

1. The source `NotificationServer` emits a versioned JSON payload on the
   `notifications.received` IPC signal.
2. `modules/notifications/bin/remote-stream` connects with non-interactive SSH
   and runs `dshell notifications listen` on the source.
3. The helper validates and bounds the app name, summary, body, and urgency,
   then calls local `notify-send`.
4. Replayed notifications carry the `x-dotshell-forwarded-from` hint. The
   destination does not publish marked notifications again, preventing loops.

The stream reconnects within five seconds after disconnecting. It forwards new
text notifications only; existing history, images, actions, and replacement
updates are not synchronized.

## IPC

```bash
dshell notifications listen
```

The command streams one compact JSON object per newly received local
notification. It uses display-independent Quickshell IPC so non-interactive SSH
sessions can subscribe.
