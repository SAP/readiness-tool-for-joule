@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Joule Import Log'
define root view entity ZZI_DRJ_IMPORTLOG
  as select from zzdrj_import_log
{
  key import_uuid       as ImportUuid,
      import_ts         as ImportTs,
      imported_by       as ImportedBy,
      file_name         as FileName,
      rows_in_file      as RowsInFile,
      caps_created      as CapsCreated,
      scenarios_created as ScenariosCreated,
      status            as Status,
      message           as Message
}
