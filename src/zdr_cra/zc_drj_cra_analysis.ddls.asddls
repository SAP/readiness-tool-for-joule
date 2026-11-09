@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis'

define root view entity ZC_DRJ_CRA_Analysis
  provider contract transactional_query
  as projection on ZR_DRJ_CRA_Analysis
{
  key AnalysisUUID,

      CreatedBy,
      CreatedAt,
      Status,
      RoleCount,
      ScenarioCount,
      ResultCount,

      _Roles :
        redirected to composition child ZC_DRJ_CRA_Role,
        
       _Results :
        redirected to composition child ZC_DRJ_CRA_Result,
        
       _Missing :
        redirected to composition child ZC_DRJ_CRA_Missing 
       
}
