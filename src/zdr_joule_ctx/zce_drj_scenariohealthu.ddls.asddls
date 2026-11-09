@EndUserText.label: 'Scenario Health - User Context'
@ObjectModel.query.implementedBy:'ABAP:ZCL_DRJ_SCEN_HEALTH_QPU'
define root custom entity ZCE_DRJ_ScenarioHealthU
{
  key CapabilityName            : abap.char(64);
  key ScenarioName              : abap.char(255);

      ContextUser               : abap.char(12);

      OverallStatus             : abap.char(40);
      OverallStatusState        : abap.char(1);

      ODataServicesTotal        : abap.int4;
      ODataServicesActive       : abap.int4;
      ODataServicesInactive     : abap.int4;
      ODataServicesAuthorized   : abap.int4;
      ODataServicesUnauthorized : abap.int4;

      SAPUI5TMsTotal            : abap.int4;
      SAPUI5TMsActive           : abap.int4;
      SAPUI5TMsInactive         : abap.int4;
      SAPUI5TMsAuthorized       : abap.int4;
      SAPUI5TMsUnauthorized     : abap.int4;

      ActSummaryState           : abap.char(1);
      ActSummary                : abap.char(100);
      ActSummaryDescription     : abap.char(255);
      ActSummaryPercentage      : abap.dec( 5, 2 );

      AuthSummaryState          : abap.char(1);
      AuthSummary               : abap.char(100);
      AuthSummaryDescription    : abap.char(255);
      AuthSummaryPercentage     : abap.dec( 5, 2 );
}
