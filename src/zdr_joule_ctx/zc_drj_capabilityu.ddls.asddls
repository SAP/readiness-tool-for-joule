@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joule Capability Consumption - User Context'

define root view entity ZC_DRJ_CapabilityU
  with parameters
    p_context_user : syuname
  as select from ZR_DRJ_Capability
  //association [0..*] to ZR_DRJ_CapabilityScenarioU as _ScenariosU on $projection.CapabilityName = _ScenariosU.CapabilityName
{
  key CapabilityName,
      CapabilityDescription,
      CapabilityDisplayName,
      Namespace,
      Version,
      DeployedVersion,
      Pattern,
      ReleaseInfo,
      JouleBase,
      Id,
      JarvisId,
      GitInfo,
      ScenarioCount,
      ApiCount,
      TargetMappingCount,
      $parameters.p_context_user as ContextUser,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DRJ_VE_CAPABILITYU'
      cast( '' as abap.char(1) ) as OverallHealth,

      _BusinessRoles
      //_ScenariosU - not supported with param passing
}
