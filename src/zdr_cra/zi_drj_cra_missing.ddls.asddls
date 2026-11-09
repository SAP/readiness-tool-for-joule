@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis Missing Requirement'

define view entity ZI_DRJ_CRA_Missing
  as select from zdrj_cra_missing

  association to parent ZR_DRJ_CRA_Analysis as _Analysis
    on $projection.AnalysisUUID = _Analysis.AnalysisUUID

{

  key analysis_uuid    as AnalysisUUID,
  key row_hash         as RowHash,

      role_name        as RoleName,
      capability_name  as CapabilityName,
      scenario_name    as ScenarioName,
      requirement_type as RequirementType,
      requirement_key  as RequirementKey,


      odata_service_name as ODataServiceName,
      api_version        as APIVersion,

      semantic_object    as SemanticObject,
      semantic_action    as SemanticAction,
      catalog_id         as CatalogID,

      _Analysis
}
