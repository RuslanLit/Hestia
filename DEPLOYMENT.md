# Hestia Deployment

## Self-Hosted TURN With coturn

WebRTC calls can connect directly on many home and office networks, but mobile
networks, CGNAT, strict NAT, and corporate firewalls often block peer-to-peer
media. A TURN server gives Hestia calls a relay path when direct ICE candidates
cannot connect.

### Install coturn on Ubuntu/Debian

```bash
sudo apt update
sudo apt install coturn
```

Enable the service:

```bash
sudo sed -i 's/^#TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
sudo systemctl enable coturn
```

### Minimal `/etc/turnserver.conf`

Replace `your-domain.com`, `username`, and `password` with your real TURN host
and credentials. Do not commit the real password to this repository.

```ini
listening-port=3478
tls-listening-port=5349
realm=your-domain.com
server-name=your-domain.com

lt-cred-mech
user=username:password
fingerprint

no-multicast-peers
no-loopback-peers

min-port=49152
max-port=65535

# Optional hardening: block relaying to private/link-local networks when your
# deployment does not need TURN clients to reach internal addresses.
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=::1
denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
```

For production `turns:` support, configure TLS certificates in coturn too:

```ini
cert=/etc/letsencrypt/live/your-domain.com/fullchain.pem
pkey=/etc/letsencrypt/live/your-domain.com/privkey.pem
```

Restart coturn after editing:

```bash
sudo systemctl restart coturn
sudo systemctl status coturn
```

### Firewall Ports

Open these ports on the TURN host:

- `3478/tcp`
- `3478/udp`
- `5349/tcp` for TLS TURN
- `49152-65535/udp` for relay media, or the smaller UDP range configured with
  `min-port` and `max-port`

Example with UFW:

```bash
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp
sudo ufw allow 5349/tcp
sudo ufw allow 49152:65535/udp
```

### Hestia Backend `TURN_SERVERS`

Set `TURN_SERVERS` in the Hestia backend environment. The format is a
comma-separated list of `url|username|password` entries:

```env
TURN_SERVERS=turn:your-domain.com:3478?transport=udp|username|password,turn:your-domain.com:3478?transport=tcp|username|password,turns:your-domain.com:5349?transport=tcp|username|password
```

Restart the Hestia backend after changing the environment.

### Verify

Open the backend config endpoint:

```bash
curl https://your-domain.com/config
```

or:

```bash
curl https://your-domain.com/api/config
```

Confirm that `iceServers` contains the built-in `stun:` entries and your
`turn:`/`turns:` entries.

Then test real calls:

- call between two devices on the same Wi-Fi
- call between devices on different Wi-Fi networks
- call from mobile network to Wi-Fi
- call from Wi-Fi to mobile network

The mobile network to Wi-Fi test is the most important one for catching CGNAT
and strict NAT issues.

### Security Notes

- Do not commit real TURN usernames or passwords.
- Use a firewall and open only the TURN ports you need.
- Restrict the UDP relay range with `min-port` and `max-port`.
- Rotate TURN credentials regularly.
- Prefer `turns:` with TLS for production deployments.
- Keep coturn and the host OS updated.
