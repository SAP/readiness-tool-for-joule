@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'Joule Capability (User Context)'

define root view entity ZR_DRJ_Cap_User 
   with parameters
    p_context_user : syuname

  as select from zdrj_capability

//  association [0..*] to ZR_DRJ_Cap_Scen_User as _Scenarios
//    on $projection.CapabilityName = _Scenarios.CapabilityName

  association [0..*] to ZI_DRJ_CapabilityBusinessRole as _BusinessRoles
    on $projection.CapabilityName = _BusinessRoles.CapabilityName

  association [0..1] to ZI_DRJ_CapScenarioCount as _ScenarioCount
    on $projection.CapabilityName = _ScenarioCount.CapabilityName

  association [0..1] to ZI_DRJ_CapApiCount as _ApiCount
    on $projection.CapabilityName = _ApiCount.CapabilityName

  association [0..1] to ZI_DRJ_CapTmCount as _TmCount
    on $projection.CapabilityName = _TmCount.CapabilityName

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

      cast(
        $parameters.p_context_user
        as syuname )               as ContextUser,

//      _Scenarios,
      _BusinessRoles

}
