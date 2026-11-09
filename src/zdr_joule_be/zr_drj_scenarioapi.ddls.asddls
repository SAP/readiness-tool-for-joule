@EndUserText.label: 'Scenario APIs'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZR_DRJ_ScenarioApi
  as select from ZI_DRJ_ScenarioApi
{
  key CapabilityName,
  key ScenarioName,
  key OdataServiceName,

      ApiExists,
      Namespace,
      ApiVersion,
      ApiMethod,
      ApiPath,

      @ObjectModel.virtualElementCalculatedBy:
        'ABAP:ZCL_DRJ_VE_SCENARIOAPI'
      cast( '' as abap.char(1) ) as ActivationStatus,

      @ObjectModel.virtualElementCalculatedBy:
        'ABAP:ZCL_DRJ_VE_SCENARIOAPI'
      cast( '' as abap.char(1) ) as AuthorizationStatus,

      _Scenario
}
