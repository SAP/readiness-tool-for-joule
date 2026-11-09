@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@EndUserText.label: 'Fetch User Details for value help selection'

define view entity ZI_DRJ_UserInfo
  as select from usr02 as UserLogon

    inner join usr21 as UserAddressKey
      on UserLogon.bname = UserAddressKey.bname

    inner join adrp as PersonName
      on UserAddressKey.persnumber = PersonName.persnumber

    left outer join adr6 as EmailData
      on  EmailData.addrnumber = UserAddressKey.addrnumber
      and EmailData.persnumber = UserAddressKey.persnumber
      and EmailData.flgdefault = 'X'
{
  key UserLogon.bname       as UserName,

      PersonName.name_first as FirstName,

      PersonName.name_last  as LastName,

      @Semantics.eMail.address: true
      EmailData.smtp_addr   as EmailAddress,

      @EndUserText.label: 'Current User'
      @Semantics.booleanIndicator: true
      case
        when UserLogon.bname = $session.user
          then 'X'
        else ' '
      end                   as CurrentUser
}
