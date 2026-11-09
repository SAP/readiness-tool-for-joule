@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Target Mapping Count per Scenario'

define view entity ZI_DRJ_ScenarioTmCount
  as select from zdrj_scen_tm
{
  key capability_name as CapabilityName,
  key scenario_name   as ScenarioName,
      count(*)        as TargetMappingCount
}
group by
  capability_name,
  scenario_name
