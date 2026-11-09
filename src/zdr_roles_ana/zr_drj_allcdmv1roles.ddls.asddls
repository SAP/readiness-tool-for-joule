@EndUserText.label: 'CDM V1 Roles'
@ObjectModel.query.implementedBy:
  'ABAP:ZCL_DRJ_CDMV1_ALL_ROLE_QUERY'
define custom entity ZR_DRJ_AllCDMV1Roles
{
  key RoleName : abap.char(225);
}
