@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Target Mapping Count per Capability'

define view entity ZI_DRJ_CapTmCount
  as select from zdrj_scen_tm
{
  key capability_name    as CapabilityName,
      count(*)           as TargetMappingCount
}
group by capability_name
