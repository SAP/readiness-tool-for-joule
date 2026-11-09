@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Custom Role Analysis Missing Requirement'

define view entity ZC_DRJ_CRA_Missing
  as projection on ZI_DRJ_CRA_Missing
{
  key AnalysisUUID,
  key RoleName,
  key CapabilityName,
  key ScenarioName,
  key RequirementType,
  key RequirementKey,

      ODataServiceName,
      APIVersion,

      SemanticObject,
      SemanticAction,
      CatalogID,

      _Analysis :
        redirected to parent ZC_DRJ_CRA_Analysis
}
