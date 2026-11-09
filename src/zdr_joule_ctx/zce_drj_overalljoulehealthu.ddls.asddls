@EndUserText.label: 'Overall Joule Health - User Context'
@ObjectModel.query.implementedBy:
  'ABAP:ZCL_DRJ_OVERALL_HEALTH_QPU'

define root custom entity ZCE_DRJ_OverallJouleHealthU
{
  key HealthId : abap.char(20);

  ContextUser : syuname;

  OverallStatus      : abap.char(40);
  OverallStatusState : abap.char(1);

  NumberOfAPIs       : abap.int4;
  APIsActive         : abap.int4;
  APIsAuthorized     : abap.int4;

  NumberOfTMs        : abap.int4;
  TMsActive          : abap.int4;
  TMsAuthorized      : abap.int4;

  AuthSummary             : abap.char(100);
  AuthSummaryDescription  : abap.char(255);
}
