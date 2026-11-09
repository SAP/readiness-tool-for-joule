# 🗺️ Tool overview

The **Readiness Inspection and Guidance Tool for Joule Scenarios** is a plug-in available through the SAP Fiori Launchpad (FLP) shell bar. It provides readiness and access information for Joule capabilities, their scenarios and the underlying system artefacts.

## The problem it addresses

A capability may contain multiple scenarios. Each scenario may depend on:

- **OData services (APIs)** that make backend data available; and
- **SAP Fiori apps / intent-based navigation (IBN) targets** that the scenario can navigate to, such as SAPUI5, WebCUIF, Web Dynpro, SAPGUI or URL targets.

Both system-level activation and user-specific authorisation matter. The tool makes these dependencies visible and shows where further administrative action is needed.

## Who uses it?

| Persona | Typical goal |
| --- | --- |
| SAP / Fiori administrator | Review landscape readiness and inactive content |
| Support engineer | Diagnose why a Joule scenario is unavailable for a user |
| Functional expert | Inspect the readiness of business capabilities |
| Security / audit team | Examine activation and authorisation visibility for a selected user |
| Authorised end user | Review their own readiness and access, where permitted |

## Core terms

| Term | Meaning |
| --- | --- |
| Capability | A high-level Joule function grouping one or more scenarios |
| Scenario / use case | A specific Joule action within a capability; both terms are used interchangeably |
| CAP-NNN / SCEN-NNNN | Tool-generated reference IDs assigned to capabilities and scenarios for internal handling and display. These do not correspond to any SAP Joule technical identifiers. |
| API / OData service | A required backend service that must be active and appropriately authorised |
| IBN target | A required SAP Fiori navigation intent, identified by semantic object and action |
| Activation / readiness | Whether a required artefact is active on the SAP system |
| Authorisation / access | Whether the logged-on or selected context user has the necessary role-based access |
| Context user | A different SAP user whose access context is analysed without changing system settings |

## Two different status indicators

### 1. Joule plug-in initialisation

| Status | Interpretation |
| --- | --- |
| Green | Joule plug-in is detected in FLP and has initialised successfully |
| Red | Joule plug-in is not detected or failed to initialise |

### 2. Capability and scenario health

| Status | Readiness | User access | Interpretation |
| --- | --- | --- | --- |
| **Green — Healthy** | Active | Authorised | Required artefacts are active and accessible |
| **Yellow — Warning** | Active | Missing authorisation | At least one required API or IBN target lacks authorisation for the user |
| **Red — Critical** | At least one artefact inactive | May also be missing | Activation issue takes precedence in the overall health status |

The health model is a diagnostic indication of prerequisite activation and access, not a functional end-to-end test. A capability becomes critical when at least one of its scenarios is critical.

## Navigating the tool

The usual path is **Capabilities Overview → Scenarios Overview → Individual Scenario Detail → analyser or Resolve Errors**. See [features](features.md) and [workflows](workflows.md).

## Primary benefits

- Consolidated readiness and user-access statistics.
- Ability to inspect another user's scenario access using read-only context simulation.
- Guided breakdowns of missing activation/authorisation requirements.
- Exportable role recommendations and capability information.
- Imports of updated reference mappings and visibility data.

[← Documentation index](README.md)
