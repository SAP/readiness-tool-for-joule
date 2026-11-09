@EndUserText.label: 'Scenario APIs - User Context'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZR_DRJ_ScenarioApiU
  with parameters
    p_context_user : syuname
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
      $parameters.p_context_user as ContextUser,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DRJ_VE_SCENARIOAPIU'
      cast( '' as abap.char(1) ) as ActivationStatus,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DRJ_VE_SCENARIOAPIU'
      cast( '' as abap.char(1) ) as AuthorizationStatus
}
