# ⚠️ Scope, assumptions and limitations

The supplied manuals establish the following limits. Preserve them when extending this repository's documentation.

## Confirmed by the supplied guides

- The plug-in diagnoses **readiness (activation)** and **basic authorisation/access** of required OData services and Fiori IBN targets.
- It provides **remediation guidance**, not automatic SAP configuration or role assignment.
- **Context-user simulation** is read-only and does not change the system's settings.
- **CRA** does not verify business, functional, organisational, application-specific or data-level authorisations.
- **Background CRA mode** is experimental and documented as tested only on S/4HANA 2025, with specific bgPF/bgRFC prerequisites.
- **Joule Admin Center visibility imports** and **SAP Note 3523238 capability mappings** serve distinct purposes.
- The supplied installation guide prohibits **production deployment** and calls for a sandbox/development system.
- The Prompt Library documentation calls for validation of Joule licence and consumption conditions before use in productive environments.

## Requires validation from the actual repository or maintainers

| Item | Why it remains open |
| --- | --- |
| Approved open-source licence | The PDFs do not establish the actual licence text or SPDX identifier |
| Support/maintenance and contribution workflow | No approved public support, SLA or contributor policy was supplied |
| Detailed backend architecture and security model | The manuals describe UI and installation, not the complete class/CDS/API data flows |
| Compatibility beyond documented environment | No validated release matrix for other S/4HANA versions/modes |
| Production certification/readiness | The installation guide explicitly restricts deployment |
| Exact implementation details for Role Federation Comparison | The feature is mentioned but not documented in depth |
| Upgrade/uninstall/rollback instructions | Not supplied |

## ✅ Safe publication checklist

- [ ] Confirm the repository URL, branch and current code matches the supplied manuals.
- [ ] Preserve the real licence, notices and contribution files already in the source repository.
- [ ] Review screenshots for customer data, usernames, hostnames and secrets before committing.
- [ ] Replace screenshot placeholders with approved high-resolution tool screenshots.
- [ ] Confirm version support and installation instructions with a developer/system owner.
- [ ] Do not publish claims of SAP support, production-readiness or functional authorisation assurance unless approved.

[← Documentation index](README.md)
