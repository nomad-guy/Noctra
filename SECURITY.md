# Security Policy

## Supported Versions

We provide active security patches and updates for the following versions of Noctra:

| Version | Supported          | Status |
| ------- | ------------------ | ------ |
| `1.0.x` | :white_check_mark: | Active production release branch |
| `< 1.0.0` | :x:              | End of Life (upgrade to latest v1.0.x) |

---

## Reporting a Vulnerability

The Noctra project team takes software security, data privacy, and cryptographic integrity seriously. If you discover a vulnerability or potential security flaw, please report it responsibly so we can remediate it before public disclosure.

### How to Report
* **GitHub Private Vulnerability Advisory (Recommended)**: Submit an advisory directly via the **Security** tab of our repository: [Security Advisories](https://github.com/nomad-guy/Noctra/security/advisories/new).
* **Direct Email**: Send details of the issue to [support@noctra.app](mailto:support@noctra.app).

### What to Include in Your Report
To help us triage and resolve the issue quickly, please provide:
1. A clear description of the vulnerability and its potential impact.
2. Step-by-step instructions, proof-of-concept script, or sample payload to reproduce the behavior.
3. Affected platform(s) (Android, Windows, Linux, iOS) and application version.
4. Any proposed remediations or patches if available.

### What to Expect
* **Acknowledgment**: We aim to acknowledge receipt of security reports within **48 hours**.
* **Assessment & Fix**: We will investigate and provide an estimated timeline for a fix.
* **Coordinated Disclosure**: Once a patch is released in a new tagged version, we will publish a security advisory acknowledging your contribution (unless you prefer anonymity).

---

## Security Architecture & Guarantees

Noctra is designed with a defense-in-depth architecture:
* **Zero Telemetry**: No user identifiers, device fingerprints, or listening analytics leave your device.
* **On-Device Machine Learning**: Neural taste models and acoustic vectors train and execute locally.
* **SSRF & Stream Host Protection**: Remote media endpoints are subject to strict host whitelisting, redirect refusal to non-whitelisted domains, and mandatory TLS/HTTPS encryption.
