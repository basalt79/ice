#!/bin/bash

function box_out() {
  local s=("$@") b w t
  t=${s[0]}       # get the title from params
  # iterate over the line and assign b the longest line
  for l in "${s[@]}"; do
    ((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  s=("${s[@]:1}") # remove the title from the array
  # w is the amount of chars for the longest line
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
  # docker rmi httpd:alpine3.19 > /dev/null
}

waitForDockerLogEntry() {
  PART_OF_LOG_MESSAGE="$1"
  CONTAINER_NAME="$2"
    box_out "WAIT FOR $CONTAINER_NAME" \
    "log = $PART_OF_LOG_MESSAGE" \
    >&2

  echo "Waiting for container to output a message containing: '$PART_OF_LOG_MESSAGE'"
  while ! docker logs $CONTAINER_NAME 2>&1 | grep -q "$PART_OF_LOG_MESSAGE"; do
    echo "$CONTAINER_NAME waiting for the container to be ready..."
    sleep 1
  done
}

portainer() {

  box_out "PORTAINER" \
    "directory = $PWD" \
    "password = $PORTAINER_PASSWORD" \
    >&2

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

  PORTAINER_JWT=$(curl -s -X  POST http://localhost:9000/api/auth \
    --header "Content-Type: application/json" \
    --data '{"username": "admin","password": "'"$PORTAINER_PASSWORD"'"}'| jq -r '.jwt')

  echo "PORTAINER_JWT: $PORTAINER_JWT"


  ENDPOINT_ID=$(curl -s -X POST http://localhost:9000/api/endpoints \
    --header "Authorization: Bearer $PORTAINER_JWT" \
    --form 'Name="local-ice"' \
    --form 'EndpointCreationType="1"' | jq '.Id')

  #echo "The ENDPOINT_ID to use: $ENDPOINT_ID"

  STACK_CONTENT=$(sed ':a;N;$!ba;s/\n/\\n/g' ice.yml)
  #echo "$STACK_CONTENT"

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

pihole() {
    box_out "PIHOLE" \
    "directory = $PWD" \
    >&2
    
    docker exec -it pihole pihole disable
    docker exec -it pihole tar --overwrite -zxvf /etc/pihole/backup.tar.gz -C /
    docker exec -it pihole pihole enable
}

main() {

  PWD=$(pwd)
  HOST_ROOT=/opt/ice/data
  PIHOLE_PASSWORD=password1234
  GRAFANA_PASSWORD=password1234
  DISCORD_WEBHOOKURL=https://discord.com/api/webhooks/1234
  PORTAINER_PASSWORD="password1234"

  box_out "ICE INSTALLER" "directory = $PWD" >&2
  
  cleanup
  portainer
  pihole

}

main "$@"; exit
