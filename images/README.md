# Reference imagery

Diagrams and portal screenshots in this directory come from the official
Microsoft Learn documentation. They are used here under fair-use attribution
to help the reader connect the lab to the canonical reference architecture.
Each image is captioned in the README with a link back to its source page.

| File | Source | Caption |
|---|---|---|
| `reference-architecture.svg` | [learn.microsoft.com — Azure DNS Private Resolver](https://learn.microsoft.com/azure/architecture/networking/architecture/azure-dns-private-resolver) | Hub-and-spoke topology with DNS Private Resolver, inbound/outbound endpoints, forwarding ruleset, on-prem connectivity. |
| `inbound-traffic-flow.svg` | [learn.microsoft.com — Azure DNS Private Resolver](https://learn.microsoft.com/azure/architecture/networking/architecture/azure-dns-private-resolver) | Traffic flow for Demo 1 (on-prem -> inbound endpoint -> Azure private DNS). |
| `outbound-traffic-flow.svg` | [learn.microsoft.com — Azure DNS Private Resolver](https://learn.microsoft.com/azure/architecture/networking/architecture/azure-dns-private-resolver) | Traffic flow for Demo 2 (Azure spoke -> outbound endpoint -> on-prem DNS). |

If you want to refresh these images, fetch the latest versions from the
source URLs. They update occasionally as the docs evolve. Keep the
attribution intact in the README when you do.
