@EndUserText.label: 'CDM V2 Roles'
@ObjectModel.query.implementedBy:
  'ABAP:ZCL_DRJ_CDMV2_ALL_ROLE_QUERY'
define custom entity ZR_DRJ_AllCDMV2Roles
{
  key RoleName : abap.char(225);
}
