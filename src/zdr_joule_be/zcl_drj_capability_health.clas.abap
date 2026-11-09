CLASS zcl_drj_capability_health DEFINITION

"            Capability Health
"            └─ get_capability_health
"            │
"            ├─ Read Data
"            │ ├─ ZI_DRJ_ScenarioApi
"            │ └─ ZI_DRJ_ScenarioTargetMapping
"            │
"            │
"            ├─ Build OData Services
"            │ ├─ LOOP APIs
"            │ │
"            │ ├─ V2 Services
"            │ │ └─ zcl_drj_service_checker=>check_odata_v2_service_act
"            │ │
"            │ ├─ V4 Services
"            │ │ └─ zcl_drj_service_checker=>check_odata_v4_service_act
"            │ │
"            │ ├─ Count Active Services
"            │ ├─ Count Inactive Services
"            │ └─ Build ty_odata_service[]
"            │
"            ├─ Build Target Mappings
"            │ ├─ LOOP TMs
"            │ │
"            │ ├─ zcl_drj_service_checker=>check_target_mapping_act
"            │ │
"            │ ├─ Count Active TMs
"            │ ├─ Count Inactive TMs
"            │ └─ Build ty_tm[]
"            │
"            └─ Build Authorization Summary
"            ├─ Auth Summary
"            └─ Auth Summary Description

  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_odata_service,
        name                 TYPE string,
        service_url          TYPE string,
        activation_status    TYPE char1,
        authorization_status TYPE char1,
        last_checked         TYPE timestampl,
      END OF ty_odata_service.

    TYPES tt_odata_services
      TYPE STANDARD TABLE OF ty_odata_service
      WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_tm,
        application_title    TYPE string,
        application_url      TYPE string,
        semantic_object      TYPE string,
        semantic_action      TYPE string,
        activation_status    TYPE char1,
        authorization_status TYPE char1,
        last_checked         TYPE timestampl,
      END OF ty_tm.

    TYPES tt_tms
      TYPE STANDARD TABLE OF ty_tm
      WITH EMPTY KEY.

    TYPES ty_percentage TYPE p LENGTH 3 DECIMALS 2.

    TYPES:
      BEGIN OF ty_capability_health,

        capability_name             TYPE zdrj_capability-capability_name, "Serves as key like unique field

        overall_status              TYPE string,
        overall_status_state        TYPE char1,

        odata_services_total        TYPE i,
        odata_services_active       TYPE i,
        odata_services_inactive     TYPE i,
        odata_services_authorized   TYPE i,
        odata_services_unauthorized TYPE i,

        sapui5_tms_total            TYPE i,
        sapui5_tms_active           TYPE i,
        sapui5_tms_inactive         TYPE i,
        sapui5_tms_authorized       TYPE i,
        sapui5_tms_unauthorized     TYPE i,

        act_summary_state           TYPE char1,
        act_summary                 TYPE string,
        act_summary_description     TYPE string,
        act_summary_percentage      TYPE ty_percentage,

        auth_summary_state          TYPE char1,
        auth_summary                TYPE string,
        auth_summary_description    TYPE string,
        auth_summary_percentage     TYPE ty_percentage,

        odata_services              TYPE tt_odata_services,
        sapui5_tms                  TYPE tt_tms,

      END OF ty_capability_health.


    CLASS-METHODS get_capability_health
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_health)   TYPE ty_capability_health.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-METHODS calculate_percentage
      IMPORTING
        iv_success           TYPE i
        iv_total             TYPE i
      RETURNING
        VALUE(rv_percentage) TYPE ty_percentage.

ENDCLASS.



CLASS zcl_drj_capability_health IMPLEMENTATION.
  METHOD get_capability_health.

    DATA:
      lt_apis TYPE TABLE OF zi_drj_scenarioapi,
      lt_tms  TYPE TABLE OF zi_drj_scenariotargetmapping.

*--------------------------------------------------------------------
* Scenario-level Target Mapping aggregation
*
* CapabilityHealth must evaluate every TM row, but ANY / ALL applies
* within each Scenario. Therefore remember the observed TM states
* per Scenario while the existing detailed TM loop is running.
*--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_scenario_tm_state,

        scenario_name    TYPE zdrj_cp_scenario-scenario_name,
        operator         TYPE zdrj_scen_tm-operator,

        act_has_success  TYPE abap_bool,
        act_has_warning  TYPE abap_bool,
        act_has_error    TYPE abap_bool,

        auth_has_success TYPE abap_bool,
        auth_has_warning TYPE abap_bool,
        auth_has_error   TYPE abap_bool,

      END OF ty_scenario_tm_state.


    DATA lt_scenario_tm_states
      TYPE HASHED TABLE OF ty_scenario_tm_state
      WITH UNIQUE KEY scenario_name.


    DATA:
      lv_capability_tm_act_state  TYPE char1,
      lv_capability_tm_auth_state TYPE char1.

    rs_health-capability_name = iv_capability_name.

*--------------------------------------------------------------------
* Read APIs
*--------------------------------------------------------------------
    SELECT *
      FROM zi_drj_scenarioapi
      WHERE capabilityname = @iv_capability_name
      INTO TABLE @lt_apis.

    rs_health-odata_services_total = lines( lt_apis ).

*--------------------------------------------------------------------
* Read Target Mappings
*--------------------------------------------------------------------
    SELECT *
      FROM zi_drj_scenariotargetmapping
      WHERE capabilityname = @iv_capability_name
      INTO TABLE @lt_tms.

    rs_health-sapui5_tms_total = lines( lt_tms ).


*--------------------------------------------------------------------
* Build OData Services
*--------------------------------------------------------------------
    LOOP AT lt_apis ASSIGNING FIELD-SYMBOL(<ls_api>).

      DATA(lv_api_activation) =
        zcl_drj_capability_validator=>gc_error.

      DATA(lv_api_auth) =
        zcl_drj_capability_validator=>gc_error.

*------------------------------------------------------------------
* API Activation + Authorization
*------------------------------------------------------------------
      CASE <ls_api>-apiversion.

        WHEN 'V2'.

          DATA(ls_v2_status) =
            zcl_drj_service_checker=>check_odata_v2_service_act(
              iv_service_name = CONV #( <ls_api>-odataservicename ) ).

          IF ls_v2_status-gw_active = abap_true
             AND ( ls_v2_status-icf_exists = abap_false
                   OR ls_v2_status-icf_active = abap_true ).

            lv_api_activation =
              zcl_drj_capability_validator=>gc_success.

          ENDIF.

          DATA(ls_v2_auth) =
            zcl_drj_service_checker=>check_odata_v2_service_auth(
              iv_service_name = CONV #( <ls_api>-odataservicename )
              iv_user         = iv_user ).

          IF ls_v2_auth-service_found = abap_true
             AND ls_v2_auth-iwsg_auth = abap_true
             AND ls_v2_auth-iwsv_auth = abap_true.

            lv_api_auth =
              zcl_drj_capability_validator=>gc_success.

          ELSE.

            lv_api_auth =
              zcl_drj_capability_validator=>gc_error.

          ENDIF.

        WHEN 'V4'.

          DATA(ls_v4_status) =
            zcl_drj_service_checker=>check_odata_v4_service_act(
              iv_group_id = CONV #( <ls_api>-odataservicename ) ).

          IF ls_v4_status-gw_active = abap_true.

            lv_api_activation =
              zcl_drj_capability_validator=>gc_success.

          ENDIF.

          DATA(ls_v4_auth) =
            zcl_drj_service_checker=>check_odata_v4_service_auth(
              iv_group_id = CONV #( <ls_api>-odataservicename )
              iv_user     = iv_user ).

          IF ls_v4_auth-service_published = abap_true
             AND ls_v4_auth-service_auth = abap_true.

            lv_api_auth =
              zcl_drj_capability_validator=>gc_success.

          ELSE.

            lv_api_auth =
              zcl_drj_capability_validator=>gc_error.

          ENDIF.

        WHEN OTHERS.

          lv_api_activation =
            zcl_drj_capability_validator=>gc_error.

          lv_api_auth =
            zcl_drj_capability_validator=>gc_warning.

      ENDCASE.

*------------------------------------------------------------------
* Count API activation
*------------------------------------------------------------------
      IF lv_api_activation = zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-odata_services_active.

      ELSE.

        ADD 1 TO rs_health-odata_services_inactive.

      ENDIF.

*------------------------------------------------------------------
* Count API authorization
*------------------------------------------------------------------
      IF lv_api_auth = zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-odata_services_authorized.

      ELSE.

        ADD 1 TO rs_health-odata_services_unauthorized.

      ENDIF.

*------------------------------------------------------------------
* Append API detail row
*------------------------------------------------------------------
      APPEND VALUE ty_odata_service(
        name                 = <ls_api>-odataservicename
        activation_status    = lv_api_activation
        authorization_status = lv_api_auth
      ) TO rs_health-odata_services.

    ENDLOOP.

*--------------------------------------------------------------------
* Build Target Mappings
*--------------------------------------------------------------------
    LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_tm>).

*------------------------------------------------------------------
* TM Activation - now catalog aware
*------------------------------------------------------------------
     DATA(ls_tm_status) =
      zcl_drj_service_checker=>check_target_mapping_act(
        iv_semantic_object = CONV #( <ls_tm>-semanticobject )
        iv_semantic_action = CONV #( <ls_tm>-semanticaction )
        iv_catalog_id      = CONV string( <ls_tm>-catalogid )
        iv_user            = VALUE syuname( ) ). "No user context: activation is system-wide

***      DATA(lv_tm_activation) =
***        zcl_drj_capability_validator=>gc_error.
***
***      IF ls_tm_status-status = zcl_drj_capability_validator=>gc_success.
***
***        lv_tm_activation =
***          zcl_drj_capability_validator=>gc_success.
***
***      ENDIF.

*------------------------------------------------------------------
* Preserve the technical TM activation result exactly as returned
* by Service Checker (S / W / E).
*
* Do not convert Warning to Error here. The detailed TM row should
* show the actual result. Scenario ANY / ALL aggregation below is
* responsible for deciding whether the activation requirement is
* ultimately satisfied and therefore whether Scenario health is Error.
*------------------------------------------------------------------
   DATA(lv_tm_activation) = ls_tm_status-status.

*------------------------------------------------------------------
* TM Authorization - now real and catalog aware
*------------------------------------------------------------------
      DATA(ls_tm_auth) =
        zcl_drj_service_checker=>check_target_mapping_auth(
          iv_semantic_object = CONV #( <ls_tm>-semanticobject )
          iv_semantic_action = CONV #( <ls_tm>-semanticaction )
          iv_catalog_id      = CONV string( <ls_tm>-catalogid )
          iv_user            = iv_user ).

      DATA(lv_tm_auth_status) = ls_tm_auth-status.

      IF lv_tm_auth_status IS INITIAL.

        lv_tm_auth_status =
          zcl_drj_capability_validator=>gc_error.

      ENDIF.

*------------------------------------------------------------------
* Aggregate TM states per Scenario
*------------------------------------------------------------------

      READ TABLE lt_scenario_tm_states
        ASSIGNING FIELD-SYMBOL(<ls_scenario_tm_state>)
        WITH TABLE KEY
          scenario_name = <ls_tm>-scenarioname.


      IF sy-subrc <> 0.

        INSERT VALUE ty_scenario_tm_state(
          scenario_name = <ls_tm>-scenarioname
          operator      = <ls_tm>-operator
        )
        INTO TABLE lt_scenario_tm_states
        ASSIGNING <ls_scenario_tm_state>.

      ENDIF.


*------------------------------------------------------------------
* Remember Activation result for this Scenario
*------------------------------------------------------------------
      CASE lv_tm_activation.

        WHEN zcl_drj_capability_validator=>gc_success.

          <ls_scenario_tm_state>-act_has_success = abap_true.


        WHEN zcl_drj_capability_validator=>gc_warning.

          <ls_scenario_tm_state>-act_has_warning = abap_true.


        WHEN zcl_drj_capability_validator=>gc_error.

          <ls_scenario_tm_state>-act_has_error = abap_true.

      ENDCASE.


*------------------------------------------------------------------
* Remember Authorization result for this Scenario
*------------------------------------------------------------------
      CASE lv_tm_auth_status.

        WHEN zcl_drj_capability_validator=>gc_success.

          <ls_scenario_tm_state>-auth_has_success = abap_true.


        WHEN zcl_drj_capability_validator=>gc_warning.

          <ls_scenario_tm_state>-auth_has_warning = abap_true.


        WHEN zcl_drj_capability_validator=>gc_error.

          <ls_scenario_tm_state>-auth_has_error = abap_true.

      ENDCASE.


*------------------------------------------------------------------
* Count TM activation
*------------------------------------------------------------------
      IF lv_tm_activation = zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-sapui5_tms_active.

      ELSE.

        ADD 1 TO rs_health-sapui5_tms_inactive.

      ENDIF.

*------------------------------------------------------------------
* Count TM authorization
*------------------------------------------------------------------
      IF lv_tm_auth_status = zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-sapui5_tms_authorized.

      ELSE.

        ADD 1 TO rs_health-sapui5_tms_unauthorized.

      ENDIF.

*------------------------------------------------------------------
* Append TM detail row
*------------------------------------------------------------------

      APPEND VALUE ty_tm(

        semantic_object      = <ls_tm>-semanticobject
        semantic_action      = <ls_tm>-semanticaction
        activation_status    = lv_tm_activation
        authorization_status = lv_tm_auth_status

      ) TO rs_health-sapui5_tms.

    ENDLOOP.



*--------------------------------------------------------------------
* Derive Capability TM health from Scenario ANY / ALL results
*--------------------------------------------------------------------

    lv_capability_tm_act_state =
      zcl_drj_capability_validator=>gc_success.

    lv_capability_tm_auth_state =
      zcl_drj_capability_validator=>gc_success.


    LOOP AT lt_scenario_tm_states
      ASSIGNING FIELD-SYMBOL(<ls_scenario_state>).

      DATA:
        lv_scenario_tm_act_state  TYPE char1,
        lv_scenario_tm_auth_state TYPE char1.

      CLEAR:
        lv_scenario_tm_act_state,
        lv_scenario_tm_auth_state.


*------------------------------------------------------------------
* Scenario TM Activation
*------------------------------------------------------------------

      IF <ls_scenario_state>-operator = 'ANY'.

        IF <ls_scenario_state>-act_has_success = abap_true.

          IF <ls_scenario_state>-act_has_warning = abap_true
             OR <ls_scenario_state>-act_has_error = abap_true.

            lv_scenario_tm_act_state =
              zcl_drj_capability_validator=>gc_warning.

          ELSE.

            lv_scenario_tm_act_state =
              zcl_drj_capability_validator=>gc_success.

          ENDIF.

        ELSE.

          lv_scenario_tm_act_state =
            zcl_drj_capability_validator=>gc_error.

        ENDIF.

      ELSE.

        "ALL / blank / unexpected:
        "preserve existing strict behaviour.
        IF <ls_scenario_state>-act_has_error = abap_true.

          lv_scenario_tm_act_state =
            zcl_drj_capability_validator=>gc_error.

        ELSE.

          lv_scenario_tm_act_state =
            zcl_drj_capability_validator=>gc_success.

        ENDIF.

      ENDIF.


*------------------------------------------------------------------
* Scenario TM Authorization
*------------------------------------------------------------------

      IF <ls_scenario_state>-operator = 'ANY'.

        IF <ls_scenario_state>-auth_has_success = abap_true.

          IF <ls_scenario_state>-auth_has_warning = abap_true
             OR <ls_scenario_state>-auth_has_error = abap_true.

            lv_scenario_tm_auth_state =
              zcl_drj_capability_validator=>gc_warning.

          ELSE.

            lv_scenario_tm_auth_state =
              zcl_drj_capability_validator=>gc_success.

          ENDIF.

        ELSE.

          lv_scenario_tm_auth_state =
            zcl_drj_capability_validator=>gc_error.

        ENDIF.

      ELSE.

        "ALL / blank / unexpected:
        "preserve existing strict behaviour.
        IF <ls_scenario_state>-auth_has_error = abap_true.

          lv_scenario_tm_auth_state =
            zcl_drj_capability_validator=>gc_error.

        ELSE.

          lv_scenario_tm_auth_state =
            zcl_drj_capability_validator=>gc_success.

        ENDIF.

      ENDIF.


*------------------------------------------------------------------
* Roll Scenario Activation up to Capability
*------------------------------------------------------------------

      IF lv_scenario_tm_act_state =
         zcl_drj_capability_validator=>gc_error.

        lv_capability_tm_act_state =
          zcl_drj_capability_validator=>gc_error.

      ELSEIF lv_scenario_tm_act_state =
               zcl_drj_capability_validator=>gc_warning
             AND lv_capability_tm_act_state <>
               zcl_drj_capability_validator=>gc_error.

        lv_capability_tm_act_state =
          zcl_drj_capability_validator=>gc_warning.

      ENDIF.


*------------------------------------------------------------------
* Roll Scenario Authorization up to Capability
*------------------------------------------------------------------

      IF lv_scenario_tm_auth_state =
         zcl_drj_capability_validator=>gc_error.

        lv_capability_tm_auth_state =
          zcl_drj_capability_validator=>gc_error.

      ELSEIF lv_scenario_tm_auth_state =
               zcl_drj_capability_validator=>gc_warning
             AND lv_capability_tm_auth_state <>
               zcl_drj_capability_validator=>gc_error.

        lv_capability_tm_auth_state =
          zcl_drj_capability_validator=>gc_warning.

      ENDIF.

    ENDLOOP.


*--------------------------------------------------------------------
* Activation Summary
*--------------------------------------------------------------------

    DATA(lv_act_total) =
      rs_health-odata_services_total +
      rs_health-sapui5_tms_total.


    DATA(lv_act_success) =
      rs_health-odata_services_active +
      rs_health-sapui5_tms_active.


    DATA(lv_act_error) =
      rs_health-odata_services_inactive +
      rs_health-sapui5_tms_inactive.


    rs_health-act_summary_percentage =
      calculate_percentage(
        iv_success = lv_act_success
        iv_total   = lv_act_total ).


    IF lv_act_total = 0.

      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_success.

      rs_health-act_summary =
        'No Activation Objects'.

      rs_health-act_summary_description =
        'No OData services or Target Mappings are maintained for this capability. Activation is treated as green.'.


*------------------------------------------------------------------
* OData activation remains strict.
* Any inactive OData service makes Capability activation Error.
*------------------------------------------------------------------
    ELSEIF rs_health-odata_services_inactive > 0.

      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-act_summary =
        'Activation Issues'.

      rs_health-act_summary_description =
        |{ lv_act_error } of { lv_act_total } activation object(s) are inactive or not fully active.|.


*------------------------------------------------------------------
* Target Mapping result uses Scenario ANY / ALL semantics.
*------------------------------------------------------------------
    ELSEIF lv_capability_tm_act_state =
           zcl_drj_capability_validator=>gc_error.

      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-act_summary =
        'Activation Issues'.

      rs_health-act_summary_description =
        |{ lv_act_error } of { lv_act_total } activation object(s) are inactive or not fully active.|.


    ELSEIF lv_capability_tm_act_state =
           zcl_drj_capability_validator=>gc_warning.

      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_warning.

      rs_health-act_summary =
        'Activation Warning'.

      rs_health-act_summary_description =
        |Some Target Mapping alternatives are inactive, but the required ANY conditions are still satisfied.|.


    ELSE.

      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_success.

      rs_health-act_summary =
        'Activation OK'.

      rs_health-act_summary_description =
        |All required activation conditions are satisfied.|.

    ENDIF.



*--------------------------------------------------------------------
* Authorization Summary
*--------------------------------------------------------------------

    DATA(lv_auth_total) =
      rs_health-odata_services_total +
      rs_health-sapui5_tms_total.


    DATA(lv_auth_success) =
      rs_health-odata_services_authorized +
      rs_health-sapui5_tms_authorized.


    DATA(lv_auth_missing) =
      rs_health-odata_services_unauthorized +
      rs_health-sapui5_tms_unauthorized.


    rs_health-auth_summary_percentage =
      calculate_percentage(
        iv_success = lv_auth_success
        iv_total   = lv_auth_total ).


    IF lv_auth_total = 0.

      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_success.

      rs_health-auth_summary =
        'No Authorization Objects'.

      rs_health-auth_summary_description =
        'No OData services or Target Mappings are maintained for this capability. Authorization is treated as green.'.


*------------------------------------------------------------------
* OData authorization remains strict.
*------------------------------------------------------------------
    ELSEIF rs_health-odata_services_unauthorized > 0.

      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-auth_summary =
        'Authorization Gaps'.

      rs_health-auth_summary_description =
        |{ lv_auth_missing } of { lv_auth_total } authorization object(s) are not fully authorized.|.


*------------------------------------------------------------------
* Target Mapping authorization uses Scenario ANY / ALL semantics.
*------------------------------------------------------------------
    ELSEIF lv_capability_tm_auth_state =
           zcl_drj_capability_validator=>gc_error.

      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-auth_summary =
        'Authorization Gaps'.

      rs_health-auth_summary_description =
        |{ lv_auth_missing } of { lv_auth_total } authorization object(s) are not fully authorized.|.


    ELSEIF lv_capability_tm_auth_state =
           zcl_drj_capability_validator=>gc_warning.

      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_warning.

      rs_health-auth_summary =
        'Authorization Warning'.

      rs_health-auth_summary_description =
        |Some Target Mapping alternatives are not authorized, but the required ANY conditions are still satisfied.|.


    ELSE.

      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_success.

      rs_health-auth_summary =
        'Authorization OK'.

      rs_health-auth_summary_description =
        |All required authorization conditions are satisfied.|.

    ENDIF.

*--------------------------------------------------------------------
* Overall Status
*
* Rule:
* 1. Activation Error   -> Overall Error
* 2. Activation Warning -> Overall Warning
* 3. Authorization Error/Warning -> Overall Warning
* 4. Otherwise -> Healthy
*--------------------------------------------------------------------

    IF rs_health-act_summary_state =
       zcl_drj_capability_validator=>gc_error.

      rs_health-overall_status_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-overall_status =
        'Error'.


    ELSEIF rs_health-act_summary_state =
           zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status_state =
        zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status =
        'Warning'.


    ELSEIF rs_health-auth_summary_state =
             zcl_drj_capability_validator=>gc_error
           OR rs_health-auth_summary_state =
             zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status_state =
        zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status =
        'Warning'.


    ELSE.

      rs_health-overall_status_state =
        zcl_drj_capability_validator=>gc_success.

      rs_health-overall_status =
        'Healthy'.

    ENDIF.

  ENDMETHOD.


  METHOD calculate_percentage.

    IF iv_total IS INITIAL.

      rv_percentage = CONV ty_percentage( '100.00' ).

    ELSE.

      rv_percentage =
        CONV ty_percentage(
          ( CONV decfloat34( iv_success ) * CONV decfloat34( 100 ) )
          / CONV decfloat34( iv_total )
        ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.

