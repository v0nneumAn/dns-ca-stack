# DNS and Certificate Lifecycle Artifacts

Selected implementation artifacts from Jasper Hale's self-managed production DNS and private PKI work.

Read the full [Internal PKI and DNS case study](https://github.com/v0nneumAn/homelab/blob/main/case-studies/internal-pki-dns/README.md) for the architecture, design trade-offs, incident investigations, and verification record.

## What is included

- `scripts/doh_proxy.py` — an 81-line standard-library DNS-to-DoH proxy handling UDP and TCP clients.
- `scripts/renew-cert-wrapper.sh` — reusable ACME renewal logic with pre-hooks, post-hooks, always-run cleanup, deployment permissions, and not-due handling.
- `examples/docker-compose.yml` — an illustrative DNS stack with a read-only, capability-free DoH proxy and Pi-hole.
- `examples/*-cert.conf` — illustrative service-specific renewal hooks and certificate deployment settings.

The scripts preserve the reviewed implementation logic. The renewal wrapper's argument construction is a small publication-time, behaviour-preserving refactor: positional parameters make ACME argument boundaries explicit and avoid glob expansion. Its hook, renewal, deployment, and failure semantics are unchanged and were verified with exact-argument harnesses.

Examples use reserved `.example` names and documentation addresses; they are not copies of live production configuration.

## Security boundaries

This repository contains no:

- private keys or production certificates;
- ACME account state;
- `.env` contents or credentials;
- real internal addresses, hostnames, or tailnet identifiers;
- offline root CA material;
- production backup or recovery image.

The DoH proxy uses HTTPS with the platform TLS trust context and forwards raw DNS messages to Cloudflare. It does not perform local recursive resolution; upstream DNSSEC validation is delegated to Cloudflare.

## Repository layout

```text
scripts/
  doh_proxy.py
  renew-cert-wrapper.sh
examples/
  README.md
  docker-compose.yml
  pihole-cert.conf
  router-cert.conf
```

## Verification

Compile the Python source:

```bash
python3 -m py_compile scripts/doh_proxy.py
```

Check wrapper syntax:

```bash
sh -n scripts/renew-cert-wrapper.sh
```

If ShellCheck is already installed:

```bash
shellcheck scripts/renew-cert-wrapper.sh
```

Validate the illustrative Compose structure using a non-secret dummy value:

```bash
PIHOLE_PASSWORD='local-validation-only' docker compose -f examples/docker-compose.yml config
```

The publication workflow also exercises `doh_query` with a fake HTTPS transport, verifies TCP response framing with `socket.socketpair()`, and tests the wrapper's failure/not-due cleanup using a temporary fake ACME client. These checks use no external service, real CA, credential, or production state.

## Important limitations

- The example Compose file mirrors inspected image choices; it is not a newly reviewed, version-pinned production baseline.
- `pihole/pihole:latest` and `python:3-alpine` should be reviewed and pinned before independent deployment.
- Local DNS records, private trust material, service-specific filesystem permissions, and firewall rules remain environment-specific.
- The DoH proxy currently has no dedicated health endpoint or Prometheus metrics.
- Do not use the examples unchanged or as a substitute for tested backups.

See [examples/README.md](examples/README.md) for substitution and secret-handling details.

## Related links

- [Full case study](https://github.com/v0nneumAn/homelab/blob/main/case-studies/internal-pki-dns/README.md)
- [Incident investigations](https://github.com/v0nneumAn/homelab/blob/main/case-studies/internal-pki-dns/incidents.md)
- [Verification and limitations](https://github.com/v0nneumAn/homelab/blob/main/case-studies/internal-pki-dns/verification.md)
- [Portfolio project](https://jasper.devsnull.net/projects/internal-pki)
- [Homelab case-study index](https://github.com/v0nneumAn/homelab)
