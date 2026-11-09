@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis Role'

define view entity ZI_DRJ_CRA_Role
  as select from zdrj_cra_role

  association to parent ZR_DRJ_CRA_Analysis as _Analysis
    on $projection.AnalysisUUID = _Analysis.AnalysisUUID
{
  key analysis_uuid as AnalysisUUID,
  key role_name     as RoleName,

      _Analysis
}
