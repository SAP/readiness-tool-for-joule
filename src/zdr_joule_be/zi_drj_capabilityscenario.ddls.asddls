@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joule Capability - Scenarios Assignment'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DRJ_CapabilityScenario 
  as select from zdrj_cp_scenario
    association [1..1] to ZR_DRJ_Capability as _Capability
      on $projection.CapabilityName = _Capability.CapabilityName
    association [0..*] to ZR_DRJ_ScenarioApi as _APIs 
      on $projection.CapabilityName = _APIs.CapabilityName
         and $projection.ScenarioName = _APIs.ScenarioName
    association [0..*] to ZI_DRJ_ScenarioTargetMapping as _TargetMappings
      on $projection.CapabilityName = _TargetMappings.CapabilityName
         and $projection.ScenarioName = _TargetMappings.ScenarioName   
    association [0..1] to ZI_DRJ_ScenarioApiCount as _ApiCount
      on  $projection.CapabilityName = _ApiCount.CapabilityName
      and $projection.ScenarioName   = _ApiCount.ScenarioName

    association [0..1] to ZI_DRJ_ScenarioTmCount as _TmCount
      on  $projection.CapabilityName = _TmCount.CapabilityName
      and $projection.ScenarioName   = _TmCount.ScenarioName        
{
  key capability_name as CapabilityName,
  key scenario_name as ScenarioName,
  scenario_description as ScenarioDescription,
  namespace as Namespace,
  target_function as TargetFunction,
  _ApiCount.ApiCount as APICount,
  _TmCount.TargetMappingCount as TargetMappingCount,
  //Associations
  _Capability,
  _APIs,
  _TargetMappings
}
