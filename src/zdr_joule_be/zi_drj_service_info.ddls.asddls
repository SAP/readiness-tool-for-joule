@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service Info'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_DRJ_Service_Info
  as select from /iwfnd/i_med_sin
  association [1..1] to icfservice as _icfservice on $projection.Value = _icfservice.icfaltnme
{
  key srv_identifier         as SrvIdentifier,
  key is_active              as IsActive,
  key name                   as Name,
  key _icfservice.icf_name   as ICFName,
  key _icfservice.icfparguid as ICFParGuid,
      value                  as Value
}

where
  name = 'BEP_SVC_EXT_SERVICE_NAME'
