@EndUserText.label: 'Capability Scenarios - User Context'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define root view entity ZR_DRJ_CapabilityScenarioU
  with parameters
    p_context_user : syuname
  as select from ZI_DRJ_CapabilityScenario

/*
  association [0..*] to ZR_DRJ_ScenarioApiU
    as _APIsU
    on  $projection.CapabilityName = _APIsU.CapabilityName
    and $projection.ScenarioName   = _APIsU.ScenarioName

  association [0..*] to ZR_DRJ_ScenarioTargetMappingU
    as _TargetMappingsU
    on  $projection.CapabilityName = _TargetMappingsU.CapabilityName
    and $projection.ScenarioName   = _TargetMappingsU.ScenarioName
*/
{
  key CapabilityName,
  key ScenarioName,
      ScenarioDescription,
      Namespace,
      TargetFunction,
      APICount,
      TargetMappingCount,
      $parameters.p_context_user as ContextUser,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DRJ_VE_CAPABILITYSCENARIOU'
      cast( '' as abap.char(1) ) as ScenarioHealthState,

      _Capability
      //_APIsU, - not supported with param passing
      //_TargetMappingsU - not supported with param passing
}
