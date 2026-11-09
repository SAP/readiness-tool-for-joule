@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joule Capability - APIs Assignment'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DRJ_ScenarioApi
  as select from zdrj_scen_api
  association [1..1] to ZI_DRJ_CapabilityScenario as _Scenario on  $projection.CapabilityName = _Scenario.CapabilityName
                                                               and $projection.ScenarioName   = _Scenario.ScenarioName
{
  key capability_name    as CapabilityName,
  key scenario_name      as ScenarioName,
  key odata_service_name as OdataServiceName,
      api_exists         as ApiExists,
      namespace          as Namespace,
      api_version        as ApiVersion,
      api_method         as ApiMethod,
      api_path           as ApiPath,
      _Scenario
}
