@EndUserText.label: 'Joule Import Log'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZZC_DRJ_IMPORTLOG
  provider contract transactional_query
  as projection on ZZI_DRJ_IMPORTLOG
{
  key ImportUuid,
      ImportTs,
      ImportedBy,
      FileName,
      RowsInFile,
      CapsCreated,
      ScenariosCreated,
      Status,
      Message
}
