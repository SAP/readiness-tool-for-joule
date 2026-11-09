@EndUserText.label: 'CRA Excel Upload Result'
define abstract entity ZI_DRJ_CRA_ExcelUploadR
{
  RolesJson        : abap.string;
  InvalidRolesJson : abap.string;

  ParsedCount      : abap.int4;
  ResolvedCount    : abap.int4;
  InvalidCount     : abap.int4;
  DuplicateCount   : abap.int4;
}
