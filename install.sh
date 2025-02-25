#!/bin/bash


cleanup() {
  docker rm -f  $(docker ps -qa)
  docker network rm -f ice_ice
  sudo rm -rf "$HOST_ROOT"/portainer
}

waitForDockerLogEntry() {
  PART_OF_LOG_MESSAGE="$1"
  CONTAINER_NAME="$2"

  echo "Waiting for container to output a message containing: '$PART_OF_LOG_MESSAGE'"
  while ! docker logs $CONTAINER_NAME 2>&1 | grep -q "$PART_OF_LOG_MESSAGE"; do
    echo "$CONTAINER_NAME waiting for the container to be ready..."
    sleep 2
  done
}

preconditions() {
  sudo -E sh -c DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin >/dev/null
  sudo usermod -aG docker $USER
}

portainer() {
  HASHED_PWD=$(docker run --rm httpd:alpine3.19 htpasswd -nbB admin $PORTAINER_PASSWORD | cut -d ":" -f 2)

  docker run -d  \
    --name=portainer \
    --restart=always \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOST_ROOT"/portainer:/data  \
    portainer/portainer-ce:lts --admin-password $HASHED_PWD


  waitForDockerLogEntry "starting HTTP server" "portainer"

  echo "LOGIN to Portainer"

  # Login to portainer and get the jwt
  PORTAINER_JWT=$(curl -s -X  POST http://localhost:9000/api/auth \
    --header "Content-Type: application/json" \
    --data '{"username": "admin","password": "'"$PORTAINER_PASSWORD"'"}'| jq -r '.jwt')

  # Create local environment local-ice and get back the id of the environment
  ENDPOINT_ID=$(curl -s -X POST http://localhost:9000/api/endpoints \
    --header "Authorization: Bearer $PORTAINER_JWT" \
    --form 'Name="local-ice"' \
    --form 'EndpointCreationType="1"' | jq '.Id')

  # read the ice yml file and prepare for posting the content via http
  STACK_CONTENT=$(sed ':a;N;$!ba;s/\n/\\n/g' ice.yml)
  # create the stack by posting the ice yml content to the just created environment
  STACK_CREATE=$(curl -X POST http://127.0.0.1:9000/api/stacks/create/standalone/string?endpointId=$ENDPOINT_ID \
    --header "Authorization: Bearer $PORTAINER_JWT" \
    --header "Content-Type: application/json" \
    --data '{
          "env": [
                  { "name": "HOST_ROOT", "value": "'"$HOST_ROOT"'" },
                  { "name": "PIHOLE_PASSWORD", "value": "'"$PIHOLE_PASSWORD"'" },
                  { "name": "WG_PUBLIC_IP", "value": "'"$WG_PUBLIC_ID"'" },
                  { "name": "WG_PASSWORD_HASH", "value": "'"$WG_PASSWORD_HASH"'" }
          ],
          "fromAppTemplate": false,
          "name": "ice",
          "stackFileContent": "'"$STACK_CONTENT"'"
  }' | jq '.')

  echo  "the stack create: $STACK_CREATE"
}

icehole() {

  waitForDockerLogEntry "Pi-hole blocking is enabled" "pihole"

  # sqlite3 /etc/pihole/gravity.db "INSERT INTO adlist (address, enabled, comment) VALUES ('https://domain.com/blocklist.txt', 1, 'comment');"

  # there will be a better way https://discourse.pi-hole.net/t/a-cli-tool-to-restore-teleporter-backup-archives/63701
  BACKUP_FILE="$PWD/data/pihole/backup.tar.gz"
  if [ -f "$BACKUP_FILE" ]; then
      echo "Backup file found [$BACKUP_FILE]. Proceeding with import..."
      docker exec -it pihole tar --overwrite -zxvf /etc/pihole/backup.tar.gz -C /etc/pihole/
      docker exec -it pihole pihole restartdns
      docker exec -it pihole pihole -g
      echo "Import completed successfully."
  else
      echo "Backup file does not exist [$BACKUP_FILE]. No action taken."
  fi
}

main() {
  PWD=$(pwd)
  


  HOST_ROOT=/opt/ice/data
  PIHOLE_PASSWORD=xxx
  PORTAINER_PASSWORD="xxx"
  WG_PUBLIC_ID=xxx 
  WG_PASSWORD=
  WG_PASSWORD_HASH=$(docker run --rm -it ghcr.io/wg-easy/wg-easy:14 wgpw xxx | cut -d"'" -f2)

  echo "using wg password hash $WG_PASSWORD_HASH"
  # preconditions
  cleanup
  portainer

}

main "$@"; exit
