# Hestia TURN/coturn Production Setup

Use TURN when STUN-only WebRTC calls connect inconsistently or fail behind
mobile networks, carrier NAT, strict NAT, VPNs, or corporate firewalls.

## Install coturn on Ubuntu

```bash
sudo apt update
sudo apt install coturn
sudo systemctl enable coturn
```

Enable the service daemon:

```bash
sudo sed -i 's/^#\?TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
```

## Open firewall ports

Open these on the server firewall and provider/security-group firewall:

```bash
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 5349/tcp
sudo ufw allow 49160:49200/udp
```

The relay UDP range must match `min-port` and `max-port` in coturn.

## Username/password configuration

Edit `/etc/turnserver.conf`:

```conf
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=YOUR_SERVER_PUBLIC_IP
external-ip=YOUR_SERVER_PUBLIC_IP
realm=hestiachat.site
server-name=hestiachat.site

fingerprint
lt-cred-mech
user=USERNAME:PASSWORD

min-port=49160
max-port=49200

no-multicast-peers
no-cli
```

Restart:

```bash
sudo systemctl restart coturn
sudo systemctl status coturn --no-pager
```

Set Hestia backend `.env`:

```env
TURN_SERVERS=turn:hestiachat.site:3478?transport=udp|USERNAME|PASSWORD,turn:hestiachat.site:3478?transport=tcp|USERNAME|PASSWORD,turns:hestiachat.site:5349?transport=tcp|USERNAME|PASSWORD
```

## Static auth secret option

For generated time-limited TURN credentials, configure coturn with:

```conf
use-auth-secret
static-auth-secret=LONG_RANDOM_SECRET
realm=hestiachat.site
```

Hestia currently expects static `url|username|credential` entries in
`TURN_SERVERS`. Use the username/password setup above unless the backend is
extended to mint temporary TURN credentials.

## Test TURN

1. Restart Hestia after editing `.env`.
2. Check config:

```bash
curl https://hestiachat.site/api/config
```

Expected:

- `features.voiceCalls=true`
- `features.videoCalls=false`
- `iceServers` contains public STUN plus `turn:`/`turns:` entries
- no `your-domain.com`, `user`, or `pass` placeholder TURN values

3. Open Trickle ICE:

```text
https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
```

4. Add the same TURN URLs, username, and credential.
5. Click **Gather candidates**.
6. Confirm at least one `relay` candidate appears.

If only `host` or `srflx` candidates appear, TURN relay is not working. Recheck
DNS, ports, firewall, `external-ip`, credentials, and coturn logs:

```bash
sudo journalctl -u coturn -n 200 --no-pager
```
