#!/usr/bin/env bash

DEMO_REPO="https://github.com/ChrisWeissmann/everest-demo"
DEMO_BRANCH="main"
DEMO_COMPOSE_FILE_NAME='docker-compose.ocpp201.yml'
DEMO_DIR="$(mktemp -d)"
DIRECTUS_API_URL="http://localhost:8055"

delete_temporary_directory() {
    rm -rf "${DEMO_DIR}"
}
trap delete_temporary_directory EXIT

if [[ ! "${DEMO_DIR}" || ! -d "${DEMO_DIR}" ]]; then
    echo 'Error: Failed to create a temporary directory for the demo.'
    exit 1
fi

#TODO remove below after initial commit
mkdir -p "${DEMO_DIR}/citrineos"
cp ./citrineos/docker-compose.yml "${DEMO_DIR}/citrineos/"
cp ./citrineos/directus-env-config.cjs "${DEMO_DIR}/citrineos/"
cp "./${DEMO_COMPOSE_FILE_NAME}" "${DEMO_DIR}/"
cp "./citrineos/init.sh" "${DEMO_DIR}/citrineos"
cp "./citrineos/.env" "${DEMO_DIR}/citrineos"
cd "${DEMO_DIR}" || exit 1

echo "Cloning EVerest from ${DEMO_REPO} into ${DEMO_DIR}/everest-demo"
if ! git clone --branch "${DEMO_BRANCH}" "${DEMO_REPO}" everest-demo; then
    echo "Failed to clone repository."
    exit 1
fi

cp "${DEMO_COMPOSE_FILE_NAME}" "everest-demo/${DEMO_COMPOSE_FILE_NAME}"


# Start CitrineOS
echo "Starting the CSMS"
pushd citrineos || exit 1
if ! docker compose --project-name citrineos-csms -f ./docker-compose.yml up -d --wait; then
    echo "Failed to start CitrineOS."
    exit 1
fi

./init.sh

popd || exit 1


pushd everest-demo || exit 1
echo "Starting the EVerest file is ${DEMO_DIR}/${DEMO_COMPOSE_FILE_NAME}"
if ! docker compose --project-name everest-ac-demo \
               --file "${DEMO_COMPOSE_FILE_NAME}" up -d --wait; then
    echo "Failed to start EVerest AC demo."
    exit 1
fi

echo "Starting Everest software in the loop simulation"
if ! docker exec everest-ac-demo-manager-1 sh /workspace/build/run-scripts/run-sil-ocpp201.sh; then
    echo "Failed to start Everest simulation."
    exit 1
fi
