@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'Joule Capability'

define root view entity ZR_DRJ_Capability
  as select from zdrj_capability
  association [0..*] to ZR_DRJ_CapabilityScenario     as _Scenarios     on $projection.CapabilityName = _Scenarios.CapabilityName
  association [0..*] to ZI_DRJ_CapabilityBusinessRole as _BusinessRoles on $projection.CapabilityName = _BusinessRoles.CapabilityName
  association [0..1] to ZI_DRJ_CapScenarioCount       as _ScenarioCount on $projection.CapabilityName = _ScenarioCount.CapabilityName
  association [0..1] to ZI_DRJ_CapApiCount            as _ApiCount      on $projection.CapabilityName = _ApiCount.CapabilityName
  association [0..1] to ZI_DRJ_CapTmCount             as _TmCount       on $projection.CapabilityName = _TmCount.CapabilityName
{
  key capability_name              as CapabilityName,
      capability_description       as CapabilityDescription,
      capability_displayname       as CapabilityDisplayName,
      namespace                    as Namespace,
      version                      as Version,
      deployed_version             as DeployedVersion,
      pattern                      as Pattern,
      release_info                 as ReleaseInfo,
      joule_base                   as JouleBase,
      id                           as Id,
      jarvis_id                    as JarvisId,
      git_info                     as GitInfo,
      _ScenarioCount.ScenarioCount as ScenarioCount,
      _ApiCount.ApiCount           as ApiCount,
      _TmCount.TargetMappingCount  as TargetMappingCount,
      /* Associations */
      _Scenarios,
      _BusinessRoles
}
