@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joule Capability - Role Assignment'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_DRJ_CapabilityBusinessRole as select from zdrj_cap_brole
  association [1..1] to ZR_DRJ_Capability as _Capability
      on $projection.CapabilityName = _Capability.CapabilityName
{
  key capability_name as CapabilityName,
  key business_role as BusinessRole,
  business_role_description as BusinessRoleDescription,
  //Assocations
  _Capability
}
