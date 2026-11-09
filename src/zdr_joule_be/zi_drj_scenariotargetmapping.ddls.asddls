@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joule Capability - TMs Assignment'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DRJ_ScenarioTargetMapping
  as select from zdrj_scen_tm
  association [1..1] to ZI_DRJ_CapabilityScenario as _Scenario on  $projection.CapabilityName = _Scenario.CapabilityName
                                                               and $projection.ScenarioName   = _Scenario.ScenarioName
{
  key capability_name        as CapabilityName,
  key scenario_name          as ScenarioName,
  key semantic_object        as SemanticObject,
  key semantic_action        as SemanticAction,
  key catalog_id             as CatalogID,
      semantic_object_exists as SemanticObjectExists,
      semantic_action_exists as SemanticActionExists,
      catalog_exists         as CatalogExists,
      tm_exists_in_catalog	 as TMExistsInCatalog,
      operator               as Operator,
      namespace              as Namespace,
      fiori_app_id           as FioriAppId,
      fal_link               as FalLink,
      _Scenario
}
