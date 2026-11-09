@EndUserText.label: 'UI5 Dependency Activation Analyzer'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DRJ_UI5_DEPENDENCY_QP'
define custom entity ZCE_DRJ_UI5_DEPENDENCY
{
  key DependencyKey  : abap.char(120);

      Sequence       : abap.int4;

      SemanticObject : /ui2/semantic_object;
      SemanticAction : /ui2/semantic_action;

      CatalogId      : abap.char(255);

      ComponentId    : abap.char(255);

      DependencyType : abap.char(30);
      ServiceName    : abap.char(255);
      ServiceVersion : abap.char(20);
      Url            : abap.char(500);

      Status         : abap.char(1);
      Success        : abap.char(1);
      StatusText     : abap.char(500);
}
