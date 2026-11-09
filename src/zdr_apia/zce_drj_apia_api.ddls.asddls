@EndUserText.label: 'API Analyzer - APIs'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DRJ_APIA_API_QP'
define custom entity ZCE_DRJ_APIA_API
{
  key ApiResultKey       : abap.char(200);

      Sequence           : abap.int4;

      ApiName            : abap.char(255);
      ApiVersion         : abap.char(40);
      ApiType            : abap.char(30);

      ApiDescription     : abap.char(255);

      ServiceName        : abap.char(255);
      ServiceVersion     : abap.char(40);
      ServiceType        : abap.char(30);

      ServiceNamespace   : abap.char(255);
      ServicePath        : abap.char(255);

      SystemAlias        : abap.char(120);

      RoleCount          : abap.int4;
      CompositeRoleCount : abap.int4;
}
