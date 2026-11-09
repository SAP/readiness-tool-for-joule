@EndUserText.label: 'Scenario Target Mappings'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define root view entity ZR_DRJ_ScenarioTargetMapping
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
  
  
  @ObjectModel.virtualElementCalculatedBy:
    'ABAP:ZCL_DRJ_VE_SCENARIOTM'
  cast( '' as abap.char(64) ) as FioriAppIdVE,


  @ObjectModel.virtualElementCalculatedBy:
    'ABAP:ZCL_DRJ_VE_SCENARIOTM'
  cast( '' as abap.char(120) ) as FioriAppName,

  @ObjectModel.virtualElementCalculatedBy:
    'ABAP:ZCL_DRJ_VE_SCENARIOTM'
  cast( '' as abap.char(1024) ) as FioriAppsLibraryLink,

  @ObjectModel.virtualElementCalculatedBy:
    'ABAP:ZCL_DRJ_VE_SCENARIOTM'
  cast( '' as abap.char(1) ) as ActivationStatus,

  @ObjectModel.virtualElementCalculatedBy:
    'ABAP:ZCL_DRJ_VE_SCENARIOTM'
  cast( '' as abap.char(1) ) as AuthorizationStatus,

    _Scenario

}
