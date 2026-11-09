@EndUserText.label: 'Target Mapping Analyzer - Business Roles'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DRJ_TMA_ROLE_QP'
define custom entity ZCE_DRJ_TMA_ROLE
{
  key RoleKey          : abap.char(160);

      Sequence         : abap.int4;

      TargetMappingKey : abap.char(120);

      SemanticObject   : /ui2/semantic_object;
      SemanticAction   : /ui2/semantic_action;

      CatalogId        : abap.char(255);
      ChipId           : abap.char(255);

      RoleName         : agr_name;
      RoleDescription  : abap.char(255);

      CatalogCount     : abap.int4;
      AppCount         : abap.int4;

      CompositeRoleCount : abap.int4;
}
