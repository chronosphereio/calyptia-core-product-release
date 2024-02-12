#!/bin/bash
set -eux
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

CALYPTIA_E2E_TEST_PLATFORM=${CALYPTIA_E2E_TEST_PLATFORM:-kind}
CALYPTIA_E2E_TEST_SET=${CALYPTIA_E2E_TEST_SET:-}
CALYPTIA_E2E_TEST_REPO_DIR=${CALYPTIA_E2E_TEST_REPO_DIR:-"$SCRIPT_DIR/.."}
CALYPTIA_E2E_TEST_K8S_VERSION=${CALYPTIA_E2E_TEST_K8S_VERSION:?}

# Recreate KIND cluster if this is non-empty
CALYPTIA_E2E_TEST_CREATE_KIND_CLUSTER=${CALYPTIA_E2E_TEST_CREATE_KIND_CLUSTER:-true}

# Set this non-empty for Actuated runners
CALYPTIA_CI_ACTUATED=${CALYPTIA_CI_ACTUATED:-}

# The following are required with vCluster mode:
# CALYPTIA_E2E_TEST_VCLUSTER_NAME=${CALYPTIA_E2E_TEST_VCLUSTER_NAME:?}
# CALYPTIA_E2E_TEST_GKE_CLUSTER_NAME=${CALYPTIA_E2E_TEST_GKE_CLUSTER_NAME:?}
# CALYPTIA_E2E_TEST_GKE_CLUSTER_ZONE=${CALYPTIA_E2E_TEST_GKE_CLUSTER_ZONE:?}
# CALYPTIA_E2E_TEST_GKE_CLUSTER_PROJECT=${CALYPTIA_E2E_TEST_GKE_CLUSTER_PROJECT:?}

# Ensure any actual BATS test variables are also exported

function testForLinux() {
    # Only intended for use on Linux/bash platforms, not macOS
  case $(uname) in
    Linux)
      echo "linux"
      ;;
    Darwin)
      echo "darwin"
      exit 1
      ;;
    Windows)
      echo "windows"
      exit 1
      ;;
    *)
      exit 1
  esac
}

function validateInputs() {
    case ${CALYPTIA_E2E_TEST_PLATFORM} in
        kind)
            echo "Detected Kind mode"
            ;;
        vcluster)
            echo "Detected vCluster mode"
            ;;
        *)
            echo "Invalid mode: $CALYPTIA_E2E_TEST_PLATFORM"
            exit 1
    esac
    if [[ -z "$CALYPTIA_CLI_VERSION" ]]; then
        echo "Invalid $CALYPTIA_CLI_VERSION"
        exit 1
    fi
    if [[ -z "$CALYPTIA_CLOUD_IMAGE" ]]; then
        echo "Invalid $CALYPTIA_CLOUD_IMAGE"
        exit 1
    fi
    if [[ -z "$CALYPTIA_CORE_OPERATOR_IMAGE" ]]; then
        echo "Invalid $CALYPTIA_CORE_OPERATOR_IMAGE"
        exit 1
    fi
    if [[ -z "$CALYPTIA_CORE_OPERATOR_FROM_CLOUD_IMAGE" ]]; then
        echo "Invalid $CALYPTIA_CORE_OPERATOR_FROM_CLOUD_IMAGE"
        exit 1
    fi
    if [[ -z "$CALYPTIA_CORE_OPERATOR_TO_CLOUD_IMAGE" ]]; then
        echo "Invalid $CALYPTIA_CORE_OPERATOR_TO_CLOUD_IMAGE"
        exit 1
    fi
    if [[ -z "$CALYPTIA_CLI_VERSION" ]]; then
        echo "Invalid $CALYPTIA_CLI_VERSION"
        exit 1
    fi
    if [[ -z "$CALYPTIA_CLI_IMAGE" ]] && [[ -z "${CALYPTIA_CLI_VERSION:-latest}" ]]; then
        echo "Invalid CLI version specified"
        exit 1
    fi
    echo "Checked all inputs"

    if ! command -v docker &> /dev/null; then
        echo "ERROR: unable to find docker installation"
        exit 1
    fi
}

function installDependencies() {
    sudo apt-get update
    sudo apt-get install -y netcat lsof parallel httpie jq time bc python3 python-is-python3 coreutils apt-transport-https ca-certificates gnupg curl sudo 

    if command -v bats &> /dev/null; then
        echo "Detected existing installation of BATS so not installing"
    else
        sudo npm install -g bats
    fi
    bats --version

    if command -v kubectl &> /dev/null; then
        echo "Detected existing kubectl installation"
    else
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        # For AMD64 / x86_64
        [[ "$(uname -m)" == "x86_64" ]] && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        # For ARM64
        [[ "$(uname -m)" == "aarch64" ]] && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
    fi
    kubectl version --client

    local test_platform="${CALYPTIA_E2E_TEST_PLATFORM:-kind}"
    if [[ "$test_platform" == "kind" ]]; then
        echo "Checking for KIND dependencies"
        if command -v kind &> /dev/null; then
            echo "KIND already installed"
        else
            echo "Installing KIND"
            # For AMD64 / x86_64
            [[ "$(uname -m)" == "x86_64" ]] && curl -sSfLo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            # For ARM64
            [[ "$(uname -m)" == "aarch64" ]] && curl -sSfLo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-arm64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
    elif [[ "$test_platform" == "vcluster" ]]; then
        echo "Checking for vCluster dependencies"
        if command -v gcloud &> /dev/null; then
            echo "Detected existing gcloud installation, ensuring we have GKE auth if required"
            gcloud components install gke-gcloud-auth-plugin
        else
            curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
            echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
            sudo apt-get update
            sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin
        fi

        if command -v vcluster &> /dev/null; then
            echo "vCluster already installed"
        else
            echo "Installing vCluster"
            # For AMD64 / x86_64
            [[ "$(uname -m)" == "x86_64" ]] && curl -sSfLo ./vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64"
            # For ARM64
            [[ "$(uname -m)" == "aarch64" ]] && curl -sSfLo ./vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-arm64"
            chmod +x ./vcluster
            sudo mv ./vcluster /usr/local/bin/vcluster
        fi
    else
        echo "Skipping any dependencies for $test_platform"
    fi
}

function trimWhitespace() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Verify test set exists
function validateTestSet() {
    # Split by comma and then verify each directory exists as a test set
    readarray -td, testset_array <<<"$CALYPTIA_E2E_TEST_SET,"; unset 'testset_array[-1]'; declare -p testset_array;

    for testset_dir in "${testset_array[@]}"
    do
        local trimmedDir
        trimmedDir=$(trimWhitespace "$testset_dir")

        if [[ -d "$CALYPTIA_E2E_TEST_REPO_DIR/bats/$trimmedDir" ]]; then
            echo "Found test set: $trimmedDir"
        else
            echo "Unable to find test set: $trimmedDir"
            exit 1
        fi
    done
}

function setupCluster() {
    local test_platform="${CALYPTIA_E2E_TEST_PLATFORM:-kind}"
    if [[ "$test_platform" == "kind" ]]; then
        if [[ -n "${CALYPTIA_E2E_TEST_CREATE_KIND_CLUSTER:-}" ]]; then
            echo "Creating a fresh KIND cluster"
            if kind delete cluster &> /dev/null; then
                echo "Deleted existing cluster"
            fi
            if [[ -n "${CALYPTIA_CI_ACTUATED:-}" ]]; then
                kind create cluster --wait 300s --config /dev/stdin <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
    - role: control-plane
      image: kindest/node:${CALYPTIA_E2E_TEST_K8S_VERSION:?}
containerdConfigPatches:
    - |-
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
        endpoint = ["http://192.168.128.1:5000"]
EOF
            else
                kind create cluster --wait 300s --config /dev/stdin <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
    - role: control-plane
      image: kindest/node:${CALYPTIA_E2E_TEST_K8S_VERSION:?}
EOF
            fi
        fi

        docker pull "$CALYPTIA_CLOUD_IMAGE"
        kind load docker-image "$CALYPTIA_CLOUD_IMAGE"

        docker pull "$CALYPTIA_CORE_IMAGE"
        kind load docker-image "$CALYPTIA_CORE_IMAGE"

        docker pull "$CALYPTIA_CORE_OPERATOR_IMAGE"
        kind load docker-image "$CALYPTIA_CORE_OPERATOR_IMAGE"

        docker pull "$CALYPTIA_CORE_OPERATOR_TO_CLOUD_IMAGE"
        kind load docker-image "$CALYPTIA_CORE_OPERATOR_TO_CLOUD_IMAGE"

        docker pull "$CALYPTIA_CORE_OPERATOR_FROM_CLOUD_IMAGE"
        kind load docker-image "$CALYPTIA_CORE_OPERATOR_FROM_CLOUD_IMAGE"
    elif [[ "$test_platform" == "vcluster" ]]; then
        echo "vCluster setup"
        gcloud container clusters get-credentials "${CALYPTIA_E2E_TEST_GKE_CLUSTER_NAME:?}" --zone "${CALYPTIA_E2E_TEST_GKE_CLUSTER_ZONE:?}" --project "${CALYPTIA_E2E_TEST_GKE_CLUSTER_PROJECT:?}"
        kubectl get ns
        # form a valid name
        local vcluster_name
        vcluster_name=$(echo "${CALYPTIA_E2E_TEST_VCLUSTER_NAME}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/^[^a-z]/a&/')
        # create vCluster
        vcluster create "$vcluster_name" \
            --set "vcluster.image=rancher/k3s:${CALYPTIA_E2E_TEST_K8S_VERSION:?}" \
            --connect=false
        # Wait for cluster to be ready
        max_attempts=30
        attempt=0
        status="ERROR: Reached maximum attempts, vCluster is not ready."

        while [ $attempt -lt $max_attempts ]; do
            output=$(kubectl get pods -l release="$vcluster_name" -A -o jsonpath="{.items[*].status.conditions[?(@.type=='Ready')].status}")

            if echo "$output" | grep -q "True"; then
                status="vCluster is ready."
                break
            fi

            if [ -z "$output" ]; then
                echo "No vCluster found yet, attempt $((attempt + 1))/$max_attempts. Waiting..."
            else
                echo "vCluster not ready yet, attempt $((attempt + 1))/$max_attempts. Waiting..."
            fi

            attempt=$((attempt + 1))
            kubectl get ns
            kubectl get pods -A --show-labels
            sleep 10
        done
        echo "$status"
        vcluster connect "$vcluster_name" &
    else
        echo "Unknown cluster type"
        exit 1
    fi

    "$CALYPTIA_E2E_TEST_REPO_DIR/helpers/setup-log-forwarding.bash"
}

function calyptiaCliInstall() {
    if command -v calyptia &> /dev/null; then
        echo "Existing Calyptia CLI installation found so skipping installation of any other version"
    else
        if [[ -n "$CALYPTIA_CLI_IMAGE" ]]; then
            echo "Installing custom Calyptia CLI version: $CALYPTIA_CLI_IMAGE"
            docker pull "$CALYPTIA_CLI_IMAGE"
            docker image save "$CALYPTIA_CLI_IMAGE" | tar --extract --wildcards --to-stdout '*/layer.tar' | tar --extract --ignore-zeros --verbose --directory="/tmp" 'calyptia'
            chmod a+x /tmp/calyptia
            sudo mv /tmp/calyptia /usr/local/bin/calyptia
        else
            CALYPTIA_CLI_VERSION="${CALYPTIA_CLI_VERSION:-latest}"
            echo "Installing Calyptia CLI version: $CALYPTIA_CLI_VERSION"
            export cli_VERSION="$CALYPTIA_CLI_VERSION"
            curl -sSfL https://raw.githubusercontent.com/calyptia/cli/main/install.sh | bash
        fi
    fi
    calyptia version
}

function cleanup() {
    local test_platform="${CALYPTIA_E2E_TEST_PLATFORM:-kind}"
    if [[ "$test_platform" == "vcluster" ]]; then
        echo "Cleanup of vCluster"

        local vcluster_name
        vcluster_name=$(echo "${CALYPTIA_E2E_TEST_VCLUSTER_NAME}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9-]/-/g' -e 's/^[^a-z]/a&/')

        vcluster delete "$vcluster_name"
    fi
}

function echoSeparator() {
    echo '-------------------------------------------------------------------------------'
}

function dumpLogs() {
    ps afx
    echoSeparator
    kubectl cluster-info || true
    echoSeparator
    kubectl get ns || true
    echoSeparator
    kubectl get pods --all-namespaces || true
    echoSeparator
    kubectl describe all -n test || true
    echoSeparator
    kubectl get pods --all-namespaces -o wide --show-labels || true
    echoSeparator
    kubectl logs "$(kubectl get pods -l "app.kubernetes.io/name=fluent-bit,app.kubernetes.io/instance=fluent-bit" -o jsonpath="{.items[0].metadata.name}")"
    echoSeparator
    wget https://raw.githubusercontent.com/johanhaleby/kubetail/master/kubetail
    /bin/bash ./kubetail --follow false --previous false --colored-output false --namespace test || true
    echoSeparator
}

function listImages() {
    # https://kubernetes.io/docs/tasks/access-application-cluster/list-all-running-container-images/
    docker images
    echoSeparator
    kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" |\
        tr -s '[:space:]' '\n' |\
        sort |\
        uniq -c
    echoSeparator
}

validateInputs
validateTestSet
testForLinux
installDependencies
calyptiaCliInstall
setupCluster

# Split by comma and then verify each directory exists as a test set
readarray -td, testset_array <<<"$CALYPTIA_E2E_TEST_SET,"; unset 'testset_array[-1]'; declare -p testset_array;

exitCode=0
for testset_dir in "${testset_array[@]}"
do
    if ! "$CALYPTIA_E2E_TEST_REPO_DIR/run-bats.sh" "$(trimWhitespace "$testset_dir")" ; then
        exitCode=1
        dumpLogs
    fi
done

listImages
cleanup

exit $exitCode

