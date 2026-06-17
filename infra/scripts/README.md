# Bicep modules — scripts

This directory holds payloads for VM extensions. They are referenced by Bicep
modules and uploaded to the VM at deploy time via Azure Custom Script
Extension.

| Script | Used by | Purpose |
|---|---|---|
| `Configure-WindowsDns.ps1` | `modules/on-prem-sim.bicep` | Installs the Windows DNS Server role on `vm-dns-server`, sets up a conditional forwarder for `privatelink.blob.core.windows.net` -> the resolver inbound endpoint (`10.0.1.4`), and creates a primary zone for the on-prem domain (default `contoso.com`) with a single A record (default `dns` -> `10.1.1.4`). |

The Bicep module fetches the script with `loadTextContent()` and inlines it
into a `commandToExecute` string. No external file URIs are required at
deploy time, so the lab works in air-gapped or restricted-network
subscriptions as long as Azure Resource Manager + AVM module pulls succeed.
