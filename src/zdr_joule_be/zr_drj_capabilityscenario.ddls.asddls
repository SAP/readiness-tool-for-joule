@EndUserText.label: 'Capability Scenarios'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define root view entity ZR_DRJ_CapabilityScenario
  as select from ZI_DRJ_CapabilityScenario

  association [0..*] to ZR_DRJ_ScenarioApi as _APIs
    on  $projection.CapabilityName = _APIs.CapabilityName
    and $projection.ScenarioName   = _APIs.ScenarioName

  association [0..*] to ZR_DRJ_ScenarioTargetMapping as _TargetMappings
    on  $projection.CapabilityName = _TargetMappings.CapabilityName
    and $projection.ScenarioName   = _TargetMappings.ScenarioName

{
  key CapabilityName,
  key ScenarioName,

  ScenarioDescription,
  Namespace,
  TargetFunction,
  APICount,
  TargetMappingCount,

  @ObjectModel.virtualElementCalculatedBy:
    'ABAP:ZCL_DRJ_VE_CAPABILITYSCENARIO'
  cast( '' as abap.char(1) ) as ScenarioHealthState,
  _Capability,
  _APIs,
  _TargetMappings

}
