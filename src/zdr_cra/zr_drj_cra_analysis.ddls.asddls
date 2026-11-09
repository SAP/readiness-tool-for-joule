@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis'

define root view entity ZR_DRJ_CRA_Analysis
  as select from zdrj_cra_hdr

  composition [0..*] of ZI_DRJ_CRA_Role as _Roles
  composition [0..*] of ZI_DRJ_CRA_Result as _Results
  composition [0..*] of ZI_DRJ_CRA_Missing as _Missing
  
{
  key analysis_uuid as AnalysisUUID,

      created_by     as CreatedBy,
      created_at     as CreatedAt,
      status         as Status,

      role_count     as RoleCount,
      scenario_count as ScenarioCount,
      result_count   as ResultCount,

      _Roles,
      _Results,
      _Missing
}
