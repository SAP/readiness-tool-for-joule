@EndUserText.label: 'Custom Role Analyzer - Role Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZI_DRJ_CRA_RoleVH
  as select from agr_define as Role

    left outer join agr_texts as RoleText
      on  RoleText.agr_name = Role.agr_name
      and RoleText.spras    = $session.system_language
      and RoleText.line     = '00000'

{
  key Role.agr_name as RoleName,

      RoleText.text as RoleDescription
}
