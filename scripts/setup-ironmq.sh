export USER_EMAIL="testing-ironmq-user@apiary-internal.com"
export USER_PASSWORD="testpassword"
export PROJECT_NAME="ivy-test-suite"
# get errors if project/user exists
docker run --net=host iron/authcli iron -t adminToken create user $USER_EMAIL $USER_PASSWORD
docker run --net=host iron/authcli iron -t $USER_TOKEN create project $PROJECT_NAME
# always works if project/user already exists
export USER_TOKEN=`docker run --net=host iron/authcli iron -t adminToken get user $USER_EMAIL |  cut -d' ' -f7 | cut -d'=' -f2 | tr -d []`
export PROJECT_ID=`docker run --net=host iron/authcli iron -t $USER_TOKEN get projects | cut -d' ' -f5 | cut -d'=' -f2`

echo "{\"token\": \"$USER_TOKEN\", \"project_id\": \"$PROJECT_ID\"}" > iron.json
