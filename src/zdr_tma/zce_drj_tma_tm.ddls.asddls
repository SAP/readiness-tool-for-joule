@EndUserText.label: 'Target Mapping Analyzer - Target Mappings'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DRJ_TMA_TM_QP'
define custom entity ZCE_DRJ_TMA_TM
{
  key TargetMappingKey : abap.char(120);

      Sequence         : abap.int4;

      SemanticObject   : /ui2/semantic_object;
      SemanticAction   : /ui2/semantic_action;

      Text             : abap.char(255);

      CatalogId        : abap.char(255);
      OriginalCatalogId: abap.char(255);

      CatalogOrigin    : abap.char(20);
      TmType           : abap.char(30);

      ApplicationType  : abap.char(30);
      TargetId         : abap.char(255);
      MappingId        : abap.char(255);

      ChipId           : abap.char(255);
      RefChipId        : abap.char(255);

      SystemAlias      : abap.char(120);
      ShortGuid        : abap.char(80);

      Scope            : abap.char(1);
      RefScope         : abap.char(1);

      UiadId           : /ui2/ad_mm_app_id;

      RoleCount        : abap.int4;
      CompositeRoleCount : abap.int4;
}
