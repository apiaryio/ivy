export USER_EMAIL="testing-ironmq-user@apiary-internal.com"
export USER_PASSWORD="testpassword"
export PROJECT_NAME="ivy-test-suite"
export USER_TOKEN=`docker run --net=host iron/authcli iron -t adminToken create user $USER_EMAIL $USER_PASSWORD | grep -o '[^=]*$'`
export PROJECT_ID=`docker run --net=host iron/authcli iron -t $USER_TOKEN create project $PROJECT_NAME | cut -d' ' -f6 | cut -d'=' -f2`

echo "{\"token\": \"$USER_TOKEN\", \"project_id\": \"$PROJECT_ID\"}" > iron.json
