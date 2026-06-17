#!/usr/bin/env bash
# teardown.sh — Remove the entire lab.
#
# Deletes the resource group containing every lab resource. Idempotent:
# safe to re-run if the first attempt was interrupted.

set -euo pipefail

RG="${1:-rg-dnslab}"

echo "About to delete resource group: $RG"
echo "This will remove ALL lab resources. Press Ctrl+C within 10 seconds to abort."
sleep 10

az group delete --name "$RG" --yes --no-wait

echo "Delete request submitted. The deletion runs asynchronously in Azure."
echo "Track progress: az group show --name $RG --query 'properties.provisioningState'"
echo "(Returns 'Deleting' until done, then 'ResourceGroupNotFound'.)"
