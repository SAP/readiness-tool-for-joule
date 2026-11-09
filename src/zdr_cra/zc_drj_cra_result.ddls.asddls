@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis Result'

define view entity ZC_DRJ_CRA_Result
  as projection on ZI_DRJ_CRA_Result
{
  key AnalysisUUID,
  key RoleName,
  key CapabilityName,
  key ScenarioName,

      Coverage,

      RequiredTM,
      CoveredTM,

      RequiredAPI,
      CoveredAPI,

      _Analysis :
        redirected to parent ZC_DRJ_CRA_Analysis
}
