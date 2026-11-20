# Source mapping and terminology notes

These Markdown pages were drafted primarily from two provided files:

- **User Guide & Feature Reference:** *Readiness Inspection and Guidance Tool for Joule Scenarios*, 28 pages (v3 supplied in this conversation).
- **Installation Guide:** *Readiness Inspection and Guidance Tool for Joule Scenarios*, 15 pages.

| Markdown page/topic | Source in supplied PDFs |
| --- | --- |
| Product purpose, personas, concepts | User Guide pp. 2–3 |
| Two distinct status indicators | User Guide pp. 4–5 |
| Capabilities/Scenarios Overview | User Guide pp. 6–10 |
| Scenario detail / APIs / IBN | User Guide pp. 10–12 |
| TMA | User Guide p. 13 |
| APIA and role match types | User Guide pp. 14–15 |
| Activation Summary / Resolve Errors | User Guide pp. 15–17 |
| Prompt Library | User Guide pp. 17–19 |
| Capability Data Sync | User Guide pp. 19–20 |
| CRA inputs, limits, analysis | User Guide pp. 20–24 |
| Admin Center visibility import | User Guide pp. 24–26 |
| Operational workflows | User Guide pp. 26–27 |
| Installation prerequisites / package | Installation Guide pp. 2–5 |
| abapGit import | Installation Guide pp. 5–9 |
| Service definition and binding activation | Installation Guide pp. 9–13 |
| PFCG role | Installation Guide pp. 13–15 |

## Editorial decisions

- The official product name from the manuals is retained throughout; "Joule Inspector" is an informal shorthand and not used as the repository's primary title.
- British English is preferred: **authorisation**, **analyse**, **artefact**, while retaining **exact UI labels** such as `Analyze Missing OData Auth` or `Resolve Errors` where applicable.
- Capability/scenario **health** and Joule plug-in **initialisation** are documented separately.
- The user guide describes a **Resolve Errors** action opening a **Troubleshooting Help** view. The newer supplied product screenshot labels the destination **Resolve Errors**. Documentation uses the screenshot's current UI title, while retaining this note about the guide.
- Installation prerequisites, production restrictions and CRA experimental status are retained without weakening them.
- Software licences, source-code architecture and production support claims are left for review because the supplied manuals are not sufficient evidence.

## Correction applied during integration

- **Service Definition name:** The draft installation guide text stated the Service Definition was named `ZAPI_JOULECAPABILITY_O2`. Inspection of the repository's `zdr_joule_be/zapi_joulecapability.srvd.xml` confirms the Service Definition is `ZAPI_JOULECAPABILITY` (without the `_O2` suffix); the Service Binding is `ZAPI_JOULECAPABILITY_O2`. The `docs/installation.md` and `docs/troubleshooting.md` pages have been corrected accordingly. Maintainers should verify this against the live system.

[← Documentation index](README.md)
