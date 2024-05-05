#!/bin/bash


# docker, jq, sqlite3

function box_out() {
  local s=("$@") b w t
  t=${s[0]}
  for l in "${s[@]}"; do
    ((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  s=("${s[@]:1}")
  echo
 tput setaf 3
  titleline=$(printf '| %s%*s%s |\n' "$(tput setaf 2)" "-$w" "$t" "$(tput setaf 3)")
  echo "/-${b//?/-}-\\
${titleline}
|-${b//?/-}-|"
  for l in "${s[@]}"; do
    printf '| %s%*s%s |\n' "$(tput setaf 4)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "\-${b//?/-}-/"
  tput sgr 0
}

cleanup() {
  box_out "cleanup" "data directory = $PWD" >&2

  docker rm -f  $(docker ps -qa)
  docker network rm -f ice_ice
  rm -r "$PWD"/data/portainer
}

waitForDockerLogEntry() {
  PART_OF_LOG_MESSAGE="$1"
  CONTAINER_NAME="$2"
  box_out "WAIT FOR $CONTAINER_NAME" "log = $PART_OF_LOG_MESSAGE" >&2

  echo "Waiting for container to output a message containing: '$PART_OF_LOG_MESSAGE'"
  while ! docker logs $CONTAINER_NAME 2>&1 | grep -q "$PART_OF_LOG_MESSAGE"; do
    echo "$CONTAINER_NAME waiting for the container to be ready..."
    sleep 2
  done
}

preconditions() {
  sudo -E sh -c DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sqlite3 jq docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-ce-rootless-extras docker-buildx-plugin >/dev/null
  sudo usermod -aG docker $USER
}


portainer() {
  box_out "PORTAINER" "directory = $PWD" "password = $PORTAINER_PASSWORD" >&2

  HASHED_PWD=$(docker run --rm httpd:alpine3.19 htpasswd -nbB admin $PORTAINER_PASSWORD | cut -d ":" -f 2)

  docker run -d  \
    --name=portainer \
    --restart=always \
    -p 9000:9000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$PWD"/data/portainer:/data  \
    portainer/portainer-ce:2.20.1 --admin-password $HASHED_PWD


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
                  { "name": "GRAFANA_PASSWORD", "value": "'"$GRAFANA_PASSWORD"'" },
                  { "name": "DISCORD_WEBHOOKURL", "value": "'"$DISCORD_WEBHOOKURL"'" }
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
  box_out "PIHOLE" "directory = $PWD"  "backup = $BACKUP_FILE" >&2
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
  box_out "ICE INSTALLER" "directory = $PWD" >&2

  HOST_ROOT=/opt/ice/data
  PIHOLE_PASSWORD=password1234
  GRAFANA_PASSWORD=password1234
  DISCORD_WEBHOOKURL=https://discord.com/api/webhooks/1234
  PORTAINER_PASSWORD="password1234"

  cleanup
  portainer
#  icehole

}

main "$@"; exit