@EndUserText.label: 'API Analyzer - Business Roles'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DRJ_APIA_ROLE_QP'
define custom entity ZCE_DRJ_APIA_ROLE
{
  key RoleResultKey          : abap.char(200);

      Sequence               : abap.int4;

      ApiName                : abap.char(255);
      ApiVersion             : abap.char(40);
      ApiType                : abap.char(30);

      ServiceName            : abap.char(255);
      ServiceVersion         : abap.char(40);
      ServiceType            : abap.char(30);

      RoleName               : agr_name;
      RoleDescription        : abap.char(255);

      AuthorizationCount     : abap.int4;
      ServiceCount           : abap.int4;

      HasWildcardAuth        : abap.char(1);
      AuthorizationMatchType : abap.char(30);

      CompositeRoleCount     : abap.int4;
}
