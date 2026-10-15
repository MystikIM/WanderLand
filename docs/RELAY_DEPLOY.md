# Running the WanderLand relay

The relay is a small program that holds sealed friend-chat messages until a friend's phone
picks them up. It cannot read them. It needs about 30 MB of RAM and a few MB of disk.

## Build

On any computer with the Dart SDK:

    cd relay
    dart pub get
    dart compile exe --target-os linux --target-arch x64 bin/relay.dart -o wanderland-relay

(If your Dart cannot cross-compile, run the same command on the Linux machine itself without
the two `--target` options.)

## Run

    ./wanderland-relay --port 8787 --bind 127.0.0.1 --data /var/lib/wanderland-relay --behind-proxy

Use `--behind-proxy` only when the relay is reached through a tunnel or proxy that passes the real
address along (Cloudflare Tunnel does). It lets the relay rate-limit each sender fairly. Never use it if the
relay can be reached directly, because then anyone could fake the address.

Keep `--bind 127.0.0.1` and put a tunnel or reverse proxy with HTTPS in front of it, so the
relay itself is never exposed directly. Check it with `curl http://127.0.0.1:8787/v1/health`
(answers `ok`).

## Keep it running (systemd)

    [Unit]
    Description=WanderLand relay
    After=network.target

    [Service]
    ExecStart=/opt/wanderland-relay/wanderland-relay --port 8787 --bind 127.0.0.1 --data /var/lib/wanderland-relay --behind-proxy
    Restart=always
    User=wanderland-relay

    [Install]
    WantedBy=multi-user.target

## HTTPS without opening a router port (Cloudflare Tunnel, free)

Install `cloudflared`, create a tunnel in the Cloudflare dashboard, and point a hostname
(for example `chat.example.org`) at `http://127.0.0.1:8787`. Then build the app with
`--dart-define=RELAY_URL=https://chat.example.org/`.

## What it stores

Only sealed bytes and a random mailbox id per friendship. No usernames, no accounts, and the relay
itself does not store or log IP addresses. (Cloudflare, which carries the traffic through the tunnel,
can see addresses and the mailbox ids in the web addresses, as any web host can.) Mail is deleted when the phone confirms it received it, or after 7 days.
Backups of the data folder are not needed; the worst case of losing it is that mail that
was still waiting is lost.
