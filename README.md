# ice


## docker
```bash
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo reboot
docker ps
```


## portainer
```bash
docker run -d \
  --name=portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/ice/portainer:/data \
  portainer/portainer-ce:latest
```

* open http://<host>:9000
* create a admin password
* select Local Enviroment

Naviage to `Stacks` -> `+ Add Stack`

* name
* ice.yml
* enter the environment variables



## .env

| Key              | Description                                           |
| ---------------- | ----------------------------------------------------- |
| HOST_ROOT        | Full qualified folder to the 'data' e.g. '/opt/myice' |
| PIHOLE_PASSWORD  | passwort to login to pihole                           |
| GRAFANA_PASSWORD | admin password for grafana                            |
