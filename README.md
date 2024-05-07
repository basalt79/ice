# ice


collection of several docker container providing the services i use and host on a local Raspberry Pi

Main Reason
* [pihole](https://pi-hole.net/) as main usecase to block unwanted traffic
* [unbound](https://github.com/NLnetLabs/unbound) as a secure open-source recursive DNS server see [here](https://docs.pi-hole.net/guides/dns/unbound/) why
* [dhcphelper](https://github.com/homeall/dhcphelper) as a DHCP Relay to get broadcast messages out
* [easy-wg](https://github.com/wg-easy/wg-easy) WireGuard and Wireguard UI combination

Monitoring
* [pihole-exporter](https://github.com/eko/pihole-exporter) to get the available data also as metrics
* [node-exporter](https://github.com/prometheus/node_exporter) to get more metrics about the Raspberry Pi
* [prometheus](https://prometheus.io/) to collect the metrics
* [grafana](https://grafana.com/) to visualize the metrics
* [diun](https://crazymax.dev/diun/) to check if there are any newer docker images available on docker hub
  
Logging
* [promtail](https://grafana.com/docs/loki/latest/send-data/promtail/) agent collect local logs and send to loki
* [loki](https://github.com/grafana/loki) to collect the logs (like Prometheus, but for logs)

Side Services
* [caddy](https://caddyserver.com/) to host a static bookmark site for the stack
* [portainer](https://www.portainer.io/) to maintain all the images and ramp up the stack

## docker on pi
```bash
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo reboot
docker ps
```

## portainer startup
### generate password for portainer admin user
```bash
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'password1234' | cut -d ":" -f 2
```

```bash
docker run -d \
  --name=portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/ice/data/portainer:/data \
  portainer/portainer-ce:2.20.1 \
  --admin-password '<the generated hashed password>'
```

* open http://<host>:9000
* create a admin password
* select Local Enviroment

Naviage to `Stacks` -> `+ Add Stack`

* add a name
* use the ice.yml as docker compose
* enter the environment variables

## .env

| Key                | Description                                                                    |
| ------------------ | ------------------------------------------------------------------------------ |
| HOST_ROOT          | Full qualified folder to the 'data' e.g. '/opt/myice'                          |
| PIHOLE_PASSWORD    | passwort to login to pihole                                                    |
| GRAFANA_PASSWORD   | admin password for grafana                                                     |
| DISCORD_WEBHOOKURL | I configured a webhook to discored to get informed about docker image versions |

