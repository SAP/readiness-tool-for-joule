@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Scenario Count per Capability'

define view entity ZI_DRJ_CapScenarioCount 
  as select from zdrj_cp_scenario
{
   key capability_name as CapabilityName,
      count(*)       as ScenarioCount
}
group by capability_name
