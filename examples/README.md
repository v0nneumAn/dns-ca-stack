# Illustrative Examples

These files preserve useful structure from the working DNS and certificate lifecycle, with real operational identifiers replaced by reserved examples.

They are **not production configuration backups** and must not be used unchanged.

## Substitutions

- `lan.example` is a reserved example domain.
- `192.0.2.x` addresses are documentation-only addresses.
- `ca.lan.example` represents a private ACME directory, not a live endpoint.
- `/srv/dns-ca-stack` and `/srv/example-certs` are generic example paths.
- `1000:1000` is a placeholder runtime UID/GID; verify the actual service mapping before using `chown`.

Map every name, address, path, UID/GID, firewall rule, certificate destination, and service manager to the target environment before considering any deployment.

## Secrets and certificates

No password, private key, ACME account, or production certificate is included.

`WEBPASSWORD` uses Compose's required-variable form so validation and deployment fail closed when `PIHOLE_PASSWORD` is missing. Keep it in a private `.env` file that is never committed:

```bash
PIHOLE_PASSWORD='local-validation-only' docker compose -f examples/docker-compose.yml config
```

The example also references private files that are deliberately absent:

- `pihole-dnsmasq/` for local records;
- `pihole-certs/tls.pem` for the assembled certificate and key.

Do not create those files from this repository's public examples alone. Generate or restore them through the appropriate private process.

## Image and deployment scope

The image choices mirror the inspected deployment (`python:3-alpine` and `pihole/pihole:latest`). They do **not** constitute a newly reviewed or version-pinned production baseline. Review and pin suitable versions before independent use.

No containers are started by this publication's verification. `docker compose config` checks structure only; it does not prove service readiness or a production deployment.
