@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis Result'

define view entity ZI_DRJ_CRA_Result
  as select from zdrj_cra_result

  association to parent ZR_DRJ_CRA_Analysis as _Analysis
    on $projection.AnalysisUUID = _Analysis.AnalysisUUID

{
  key analysis_uuid   as AnalysisUUID,
  key role_name       as RoleName,
  key capability_name as CapabilityName,
  key scenario_name   as ScenarioName,

      coverage        as Coverage,

      required_tm     as RequiredTM,
      covered_tm      as CoveredTM,

      required_api    as RequiredAPI,
      covered_api     as CoveredAPI,

      _Analysis
}
