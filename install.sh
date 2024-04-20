#!/bin/sh

# jq required

PWD=$(pwd)
PORTAINER_PASSWORD="password1234"
HASHED_PWD=$(docker run --rm httpd:alpine3.19 htpasswd -nbB admin $PORTAINER_PASSWORD | cut -d ":" -f 2)

HOST_ROOT=/opt/ice/data
PIHOLE_PASSWORD=password1234
GRAFANA_PASSWORD=password1234
DISCORD_WEBHOOKURL=https://discord.com/api/webhooks/1234

rm -r "$PWD"/data/portainer
docker rm -f portainer > /dev/null
# docker rmi httpd:alpine3.19 > /dev/null

echo "GENERATED_PWD: $HASHED_PWD"
echo "CURRENT DIR: $PWD"

docker run -d  \
  --name=portainer \
  --restart=always \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD"/data/portainer:/data  \
  portainer/portainer-ce:2.20.1 --admin-password $HASHED_PWD


# Wait for the specific part of the log message
PART_OF_LOG_MESSAGE="starting HTTP server"
echo "Waiting for container to output a message containing: '$PART_OF_LOG_MESSAGE'"
while ! docker logs portainer 2>&1 | grep -q "$PART_OF_LOG_MESSAGE"; do
  echo "Still waiting for the container to be ready..."
  sleep 1
done

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