@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joule Capability Consumption'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZC_DRJ_Capability 
  as projection on ZR_DRJ_Capability
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
  /* Virtual Elements */
  @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_DRJ_VE_CAPABILITY'
  virtual OverallHealth : abap.char(1),
  /* Associations */
  _BusinessRoles,
  _Scenarios
}
