@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'API Count per Capability'

define view entity ZI_DRJ_CapApiCount
  as select from zdrj_scen_api
{
  key capability_name as CapabilityName,
      count(*)        as ApiCount
}
group by capability_name
