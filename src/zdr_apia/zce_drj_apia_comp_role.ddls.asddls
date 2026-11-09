@EndUserText.label: 'API Analyzer - Composite Roles'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DRJ_APIA_COMP_ROLE_QP'
define custom entity ZCE_DRJ_APIA_COMP_ROLE
{
  key CompositeRoleResultKey   : abap.char(200);

      Sequence                 : abap.int4;

      ApiName                  : abap.char(255);
      ApiVersion               : abap.char(40);
      ApiType                  : abap.char(30);

      ServiceName              : abap.char(255);
      ServiceVersion           : abap.char(40);
      ServiceType              : abap.char(30);

      RoleName                 : agr_name;
      CompositeRoleName        : agr_name;

      CompositeRoleDescription : abap.char(255);

      RolesContained           : abap.int4;

      ExcludeOwnMenu           : abap.char(1);
}
