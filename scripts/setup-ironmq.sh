export USER_EMAIL="test-ironmq-users@apiary-internal.com"
export USER_PASSWORD="testpassword"
export PROJECT_NAME="ivy-test"
export USER_TOKEN=`docker run --net=host iron/authcli iron -t adminToken create user $USER_EMAIL $USER_PASSWORD | grep -o '[^=]*$'`

docker run --net=host iron/authcli iron -t $USER_TOKEN create project $PROJECT_NAME

echo "{\"token\": \"$USER_TOKEN\", \"project_id\": \"$PROJECT_NAME\"}" > iron.json
