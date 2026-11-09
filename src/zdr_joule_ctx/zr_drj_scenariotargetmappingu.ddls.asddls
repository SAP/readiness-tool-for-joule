@EndUserText.label: 'Scenario Target Mappings - User Context'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define root view entity ZR_DRJ_ScenarioTargetMappingU
  with parameters
    p_context_user : syuname
  as select from ZI_DRJ_ScenarioTargetMapping
{
  key CapabilityName,
  key ScenarioName,
  key SemanticObject,
  key SemanticAction,
  key CatalogID,
      SemanticObjectExists,
      SemanticActionExists,
      CatalogExists,
      TMExistsInCatalog,
      Operator,
      Namespace,
      FioriAppId,
      FalLink,
      $parameters.p_context_user   as ContextUser,

      @ObjectModel.virtualElementCalculatedBy:
        'ABAP:ZCL_DRJ_VE_SCENARIOTMU'
      cast( '' as abap.char(64) )  as FioriAppIdVE,

      @ObjectModel.virtualElementCalculatedBy:
        'ABAP:ZCL_DRJ_VE_SCENARIOTMU'
      cast( '' as abap.char(120) ) as FioriAppName,

      @ObjectModel.virtualElementCalculatedBy:'ABAP:ZCL_DRJ_VE_SCENARIOTMU'
       cast( '' as abap.char(1024) ) as FioriAppsLibraryLink,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DRJ_VE_SCENARIOTMU'
      cast( '' as abap.char(1) )   as ActivationStatus,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DRJ_VE_SCENARIOTMU'
      cast( '' as abap.char(1) )   as AuthorizationStatus
}
