@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis Role'

define view entity ZC_DRJ_CRA_Role
  as projection on ZI_DRJ_CRA_Role
{
  key AnalysisUUID,
  key RoleName,

      _Analysis :
        redirected to parent ZC_DRJ_CRA_Analysis
}
