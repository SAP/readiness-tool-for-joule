@EndUserText.label: 'Target Mapping Analyzer - Composite Roles'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DRJ_TMA_COMP_ROLE_QP'
define custom entity ZCE_DRJ_TMA_COMP_ROLE
{
  key CompositeRoleKey : abap.char(160);

      Sequence         : abap.int4;

      RoleName         : agr_name;
      CompositeRoleName: agr_name;

      CompositeRoleDescription : abap.char(255);

      RolesContained   : abap.int4;

      ExcludeOwnMenu   : abap.char(1);
}
