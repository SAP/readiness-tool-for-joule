@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'API Count per Scenario'

define view entity ZI_DRJ_ScenarioApiCount 
as select from zdrj_scen_api
{
  key capability_name as CapabilityName,
  key scenario_name   as ScenarioName,
      count(*)        as ApiCount
}
group by
  capability_name,
  scenario_name
