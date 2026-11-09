# 🔁 Reference data and synchronisation

The tool uses imported reference information to relate Joule capabilities/scenarios to prerequisites. Two upload functions in the user guide serve **different purposes**.

## Capability Data Sync — SAP Note 3523238

The guide identifies SAP Note **3523238** as the source for mappings of navigational and transactional Joule capabilities to **IBN targets and APIs**.

1. Obtain the current **Business Roles and API for Transactional Capabilities.xlsx** from the note.
2. Open **Capability Data Sync** from Capabilities Overview.
3. In **Upload**, choose the Excel file (the documented maximum is **10 MB**) and import it.
4. Examine progress, **Import History** and **View Logs** for errors or unsupported values.
5. Use **Export** to download the currently held mapping data as a backup or a custom-capability template.

The guide describes an import history showing timestamp, filename, rows, capability/scenario counts, user, status and detailed logs for the latest 20 imports.

## Joule Admin Center — scenario visibility import

This separate screen imports a Joule Admin Center export containing scenario **visibility-condition information**. After successful import, the guide says the results are grouped in a capability labelled **Joule Admin Center – Data**.

**Do not confuse these data sets:** the Admin Center export helps describe whether scenarios are recognised/triggered for queries; it **does not replace or supplement** the API/IBN reference mapping from SAP Note 3523238 for readiness and authorisation analysis.

## Operations checklist

- Confirm which source and Excel version is being imported.
- Inspect the result and its detailed log instead of assuming success from upload completion.
- Keep appropriate backup exports in line with your organisation's policy.
- Investigate errors relating to unsupported content, unexpected formats or unrecognised values.

[← Documentation index](README.md)
