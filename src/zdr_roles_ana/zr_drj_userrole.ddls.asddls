@EndUserText.label: 'User Roles'
@ObjectModel.query.implementedBy:
  'ABAP:ZCL_DRJ_USER_ROLE_QUERY'
define custom entity ZR_DRJ_UserRole
{
  key UserName                    : abap.char(12);
  key RoleName                    : abap.char(30);
      RoleText                    : abap.char(80);
      ValidFrom                   : abap.dats;
      ValidTo                     : abap.dats;
      IsValid                     : abap_boolean;
      IsExcluded                  : abap_boolean;
      IsOrganisationalAssignment : abap_boolean;
      IsCompositeAssignment       : abap_boolean;
}
