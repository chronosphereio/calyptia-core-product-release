#!/bin/bash
set -eux

function gcp_create_vm() {
  local vm_name=$1
  local image=$2
  local description=${3:-"Created using image: $image_family"}

  # Clean up any existing ones
  gcloud compute instances delete "$vm_name" -q &>/dev/null || true

  if [[ "$image" == project* ]]; then
    echo "Creating VM: $vm_name (from $image)"
    gcloud compute instances create "$vm_name" \
      --image="$image" \
      --description="$description" \
      --machine-type=c2-standard-4 \
      --boot-disk-size 250GB
  else
    # Split around the /
    local image_project=${image%%/*}
    local image_family=${image##*/}
    echo "Creating VM: $vm_name (from $image_family and $image_project)"
    gcloud compute instances create "$vm_name" \
      --image-project="$image_project" \
      --image-family="$image_family" \
      --image-family-scope=global \
      --description="$description" \
      --machine-type=c2-standard-4 \
      --boot-disk-size 250GB
  fi

  echo "Waiting for SSH access to $vm_name..."
  until gcloud compute ssh "$vm_name" -q --command="true" &>/dev/null; do
      echo -n '.'
      sleep 10
  done
  echo
  echo "Successfully connected to $vm_name"

  gcloud compute ssh "$vm_name" -q --command='echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" | sudo tee -a /etc/environment' &>/dev/null || true
}

gcp_create_vm "${VM_NAME:-self-hosted-vm}" 'ubuntu-os-cloud/ubuntu-2204-lts' "${VM_DESCRIPTION:-Self hosted stack VM}"
