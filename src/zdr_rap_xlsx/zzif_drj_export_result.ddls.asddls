define abstract entity ZZIF_DRJ_EXPORT_RESULT {
  file_content  : abap.string(0);
  file_name     : abap.char(256);
  mime_type     : abap.char(128);
  rows_exported : abap.int4;
}
