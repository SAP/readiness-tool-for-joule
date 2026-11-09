CLASS zcl_drj_scenario_health DEFINITION
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

    TYPES tt_odata_services TYPE STANDARD TABLE OF ty_odata_service
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

    TYPES tt_tms TYPE STANDARD TABLE OF ty_tm
      WITH EMPTY KEY.

    TYPES ty_percentage TYPE p LENGTH 3 DECIMALS 2.

    TYPES:
      BEGIN OF ty_scenario_health,

        capability_name             TYPE zdrj_capability-capability_name,
        scenario_name               TYPE zdrj_cp_scenario-scenario_name,

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

      END OF ty_scenario_health.

    CLASS-METHODS get_scenario_health
      IMPORTING
        iv_capability_name TYPE zdrj_capability-capability_name
        iv_scenario_name   TYPE zdrj_cp_scenario-scenario_name
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_health)   TYPE ty_scenario_health.

  PROTECTED SECTION.

  PRIVATE SECTION.


    CLASS-METHODS calculate_percentage
      IMPORTING
        iv_success           TYPE i
        iv_total             TYPE i
      RETURNING
        VALUE(rv_percentage) TYPE ty_percentage.

ENDCLASS.



CLASS zcl_drj_scenario_health IMPLEMENTATION.

  METHOD get_scenario_health.

    DATA:
      lt_apis TYPE TABLE OF zi_drj_scenarioapi,
      lt_tms  TYPE TABLE OF zi_drj_scenariotargetmapping.

    DATA lv_last_checked TYPE timestampl.

    GET TIME STAMP FIELD lv_last_checked.

    rs_health-capability_name = iv_capability_name.
    rs_health-scenario_name   = iv_scenario_name.

*--------------------------------------------------------------------
* APIs
*--------------------------------------------------------------------
    SELECT *
      FROM zi_drj_scenarioapi
      WHERE capabilityname = @iv_capability_name
        AND scenarioname   = @iv_scenario_name
      INTO TABLE @lt_apis.

    rs_health-odata_services_total = lines( lt_apis ).

*--------------------------------------------------------------------
* Target Mappings
*--------------------------------------------------------------------
    SELECT *
      FROM zi_drj_scenariotargetmapping
      WHERE capabilityname = @iv_capability_name
        AND scenarioname   = @iv_scenario_name
      INTO TABLE @lt_tms.

    rs_health-sapui5_tms_total = lines( lt_tms ).

*--------------------------------------------------------------------
* Scenario Target Mapping Operator
*--------------------------------------------------------------------

    DATA lv_tm_operator TYPE zdrj_scen_tm-operator.

    IF lt_tms IS NOT INITIAL.
      "Assuming all TMs have the same operator for the scenario which can be ALL, ANY, or NONE. We take the operator from the first entry.
      lv_tm_operator = lt_tms[ 1 ]-operator.
    ENDIF.


*--------------------------------------------------------------------
* OData Validation
*--------------------------------------------------------------------
    LOOP AT lt_apis ASSIGNING FIELD-SYMBOL(<ls_api>).

      DATA(lv_activation_status) =
        zcl_drj_capability_validator=>gc_error.

      DATA(lv_auth_status) =
        zcl_drj_capability_validator=>gc_error.

      CASE <ls_api>-apiversion.

        WHEN 'V2'.

          DATA(ls_v2_status) =
            zcl_drj_service_checker=>check_odata_v2_service_act(
              iv_service_name =
                CONV #( <ls_api>-odataservicename ) ).

          IF ls_v2_status-gw_active = abap_true
             AND ( ls_v2_status-icf_exists = abap_false
                   OR ls_v2_status-icf_active = abap_true ).

            lv_activation_status =
              zcl_drj_capability_validator=>gc_success.

          ENDIF.

          DATA(ls_v2_auth) =
            zcl_drj_service_checker=>check_odata_v2_service_auth(
              iv_service_name = CONV #( <ls_api>-odataservicename )
              iv_user         = iv_user ).

          IF ls_v2_auth-iwsg_auth = abap_true
             AND ls_v2_auth-iwsv_auth = abap_true.

            lv_auth_status =
              zcl_drj_capability_validator=>gc_success.

          ELSEIF ls_v2_auth-iwsg_auth = abap_true
              OR ls_v2_auth-iwsv_auth = abap_true.

            lv_auth_status =
              zcl_drj_capability_validator=>gc_warning.

          ENDIF.

        WHEN 'V4'.

          DATA(ls_v4_status) =
            zcl_drj_service_checker=>check_odata_v4_service_act(
              iv_group_id =
                CONV #( <ls_api>-odataservicename ) ).

          IF ls_v4_status-gw_active = abap_true.

            lv_activation_status =
              zcl_drj_capability_validator=>gc_success.

          ENDIF.

          DATA(ls_v4_auth) =
            zcl_drj_service_checker=>check_odata_v4_service_auth(
              iv_group_id = CONV #( <ls_api>-odataservicename )
              iv_user     = iv_user ).

          IF ls_v4_auth-service_auth = abap_true.

            lv_auth_status =
              zcl_drj_capability_validator=>gc_success.

          ENDIF.

        WHEN OTHERS.

          lv_activation_status =
            zcl_drj_capability_validator=>gc_error.

          lv_auth_status =
            zcl_drj_capability_validator=>gc_error.

      ENDCASE.

*--------------------------------------------------------------------
* OData Activation Counters
*--------------------------------------------------------------------
      IF lv_activation_status =
         zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-odata_services_active.

      ELSE.

        ADD 1 TO rs_health-odata_services_inactive.

      ENDIF.

*--------------------------------------------------------------------
* OData Authorization Counters
*--------------------------------------------------------------------
      IF lv_auth_status =
         zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-odata_services_authorized.

      ELSE.

        ADD 1 TO rs_health-odata_services_unauthorized.

      ENDIF.

      APPEND VALUE ty_odata_service(
        name                 = <ls_api>-odataservicename
        activation_status    = lv_activation_status
        authorization_status = lv_auth_status
        last_checked         = lv_last_checked
      ) TO rs_health-odata_services.

    ENDLOOP.

*--------------------------------------------------------------------
* TM Validation
*--------------------------------------------------------------------

    DATA:
      lv_tm_act_has_success  TYPE abap_bool,
      lv_tm_act_has_warning  TYPE abap_bool,
      lv_tm_act_has_error    TYPE abap_bool,

      lv_tm_auth_has_success TYPE abap_bool,
      lv_tm_auth_has_warning TYPE abap_bool,
      lv_tm_auth_has_error   TYPE abap_bool,

      lv_tm_act_state        TYPE char1,
      lv_tm_auth_state       TYPE char1.


    LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_tm>).

      DATA(ls_tm_status) =
          zcl_drj_service_checker=>check_target_mapping_act(
            iv_semantic_object =
              CONV #( <ls_tm>-semanticobject )
            iv_semantic_action =
              CONV #( <ls_tm>-semanticaction )
            iv_catalog_id =
              CONV string( <ls_tm>-catalogid )
            iv_user = VALUE syuname( ) ). "No user context: activation is system-wide

      DATA(lv_tm_activation) =
        ls_tm_status-status.

*--------------------------------------------------------------------
* TM Authorization
*
* Catalog is passed for context/future use, but authorization is
* currently evaluated using User + Semantic Object + Action.
*--------------------------------------------------------------------
      DATA(ls_tm_auth) =
        zcl_drj_service_checker=>check_target_mapping_auth(
          iv_semantic_object = CONV #( <ls_tm>-semanticobject )
          iv_semantic_action = CONV #( <ls_tm>-semanticaction )
          iv_catalog_id      = CONV string( <ls_tm>-catalogid )
          iv_user            = iv_user ).

      DATA(lv_tm_auth) =
        ls_tm_auth-status.


*--------------------------------------------------------------------
* Remember TM Activation states
*--------------------------------------------------------------------

      CASE lv_tm_activation.

        WHEN zcl_drj_capability_validator=>gc_success.

          lv_tm_act_has_success = abap_true.

        WHEN zcl_drj_capability_validator=>gc_warning.

          lv_tm_act_has_warning = abap_true.

        WHEN OTHERS.

          lv_tm_act_has_error = abap_true.

      ENDCASE.


*--------------------------------------------------------------------
* Remember TM Authorization states
*--------------------------------------------------------------------

      CASE lv_tm_auth.

        WHEN zcl_drj_capability_validator=>gc_success.

          lv_tm_auth_has_success = abap_true.

        WHEN zcl_drj_capability_validator=>gc_warning.

          lv_tm_auth_has_warning = abap_true.

        WHEN OTHERS.

          lv_tm_auth_has_error = abap_true.

      ENDCASE.


*--------------------------------------------------------------------
* TM Activation Counters
*--------------------------------------------------------------------

      IF lv_tm_activation =
         zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-sapui5_tms_active.

      ELSE.

        ADD 1 TO rs_health-sapui5_tms_inactive.

      ENDIF.


*--------------------------------------------------------------------
* TM Authorization Counters
*--------------------------------------------------------------------

      IF lv_tm_auth =
         zcl_drj_capability_validator=>gc_success.

        ADD 1 TO rs_health-sapui5_tms_authorized.

      ELSE.

        ADD 1 TO rs_health-sapui5_tms_unauthorized.

      ENDIF.


      APPEND VALUE ty_tm(
        semantic_object      = <ls_tm>-semanticobject
        semantic_action      = <ls_tm>-semanticaction
        activation_status    = lv_tm_activation
        authorization_status = lv_tm_auth
        last_checked         = lv_last_checked
      ) TO rs_health-sapui5_tms.

    ENDLOOP.


*--------------------------------------------------------------------
* Determine Scenario TM Activation State
*--------------------------------------------------------------------

    IF lt_tms IS INITIAL.

      "No TMs means no TM-related problem.
      lv_tm_act_state =
        zcl_drj_capability_validator=>gc_success.

    ELSEIF lv_tm_operator = 'ANY'.

      IF lv_tm_act_has_success = abap_true.

        IF lv_tm_act_has_error = abap_true
           OR lv_tm_act_has_warning = abap_true.

          "At least one alternative works, but not all.
          lv_tm_act_state =
            zcl_drj_capability_validator=>gc_warning.

        ELSE.

          "All alternatives work.
          lv_tm_act_state =
            zcl_drj_capability_validator=>gc_success.

        ENDIF.

      ELSE.

        "No alternative is fully working.
        lv_tm_act_state =
          zcl_drj_capability_validator=>gc_error.

      ENDIF.

    ELSE.

      "ALL / blank / unexpected operator:
      "preserve strict behaviour.
      IF lv_tm_act_has_error = abap_true.

        lv_tm_act_state =
          zcl_drj_capability_validator=>gc_error.

      ELSEIF lv_tm_act_has_warning = abap_true.

        lv_tm_act_state =
          zcl_drj_capability_validator=>gc_warning.

      ELSE.

        lv_tm_act_state =
          zcl_drj_capability_validator=>gc_success.

      ENDIF.

    ENDIF.


*--------------------------------------------------------------------
* Determine Scenario TM Authorization State
*--------------------------------------------------------------------

    IF lt_tms IS INITIAL.

      lv_tm_auth_state =
        zcl_drj_capability_validator=>gc_success.

    ELSEIF lv_tm_operator = 'ANY'.

      IF lv_tm_auth_has_success = abap_true.

        IF lv_tm_auth_has_error = abap_true
           OR lv_tm_auth_has_warning = abap_true.

          "At least one alternative is authorized,
          "but not all alternatives are authorized.
          lv_tm_auth_state =
            zcl_drj_capability_validator=>gc_warning.

        ELSE.

          lv_tm_auth_state =
            zcl_drj_capability_validator=>gc_success.

        ENDIF.

      ELSE.

        "No alternative is fully authorized.
        lv_tm_auth_state =
          zcl_drj_capability_validator=>gc_error.

      ENDIF.

    ELSE.

      "ALL / blank / unexpected operator:
      "preserve strict behaviour.
      IF lv_tm_auth_has_error = abap_true.

        lv_tm_auth_state =
          zcl_drj_capability_validator=>gc_error.

      ELSEIF lv_tm_auth_has_warning = abap_true.

        lv_tm_auth_state =
          zcl_drj_capability_validator=>gc_warning.

      ELSE.

        lv_tm_auth_state =
          zcl_drj_capability_validator=>gc_success.

      ENDIF.

    ENDIF.

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
        'No OData services or Target Mappings are maintained for this scenario. Activation is treated as green.'.


    ELSEIF rs_health-odata_services_inactive > 0.

      "OData activation remains a hard prerequisite.
      "Any inactive OData service makes activation Error.
      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-act_summary =
        'Activation Issues'.

      rs_health-act_summary_description =
        |{ lv_act_error } of { lv_act_total } activation object(s) are inactive or not fully active.|.


    ELSEIF lv_tm_act_state =
           zcl_drj_capability_validator=>gc_error.

      "Target Mapping group itself is not satisfied.
      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-act_summary =
        'Activation Issues'.

      rs_health-act_summary_description =
        |Target Mapping activation requirements are not satisfied for this scenario.|.


    ELSEIF lv_tm_act_state =
           zcl_drj_capability_validator=>gc_warning.

      "ANY case: at least one alternative works,
      "but not every Target Mapping works.
      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_warning.

      rs_health-act_summary =
        'Activation Warning'.

      rs_health-act_summary_description =
        |At least one Target Mapping alternative is active, but not all Target Mappings are active.|.


    ELSE.

      rs_health-act_summary_state =
        zcl_drj_capability_validator=>gc_success.

      rs_health-act_summary =
        'Activation OK'.

      rs_health-act_summary_description =
        |All required activation checks are satisfied.|.

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
        'No OData services or Target Mappings are maintained for this scenario. Authorization is treated as green.'.


    ELSEIF rs_health-odata_services_unauthorized > 0.

      "OData authorization remains strict.
      "Any OData authorization issue makes the authorization
      "summary Error.
      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-auth_summary =
        'Authorization Gaps'.

      rs_health-auth_summary_description =
        |{ lv_auth_missing } of { lv_auth_total } authorization object(s) are not fully authorized.|.


    ELSEIF lv_tm_auth_state =
           zcl_drj_capability_validator=>gc_error.

      "Target Mapping authorization requirements are not satisfied.
      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_error.

      rs_health-auth_summary =
        'Authorization Gaps'.

      rs_health-auth_summary_description =
        |Target Mapping authorization requirements are not satisfied for this scenario.|.


    ELSEIF lv_tm_auth_state =
           zcl_drj_capability_validator=>gc_warning.

      "ANY case: at least one Target Mapping alternative is
      "authorized, but not all alternatives are authorized.
      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_warning.

      rs_health-auth_summary =
        'Authorization Warning'.

      rs_health-auth_summary_description =
        |At least one Target Mapping alternative is authorized, but not all Target Mappings are authorized.|.


    ELSE.

      rs_health-auth_summary_state =
        zcl_drj_capability_validator=>gc_success.

      rs_health-auth_summary =
        'Authorization OK'.

      rs_health-auth_summary_description =
        |All required authorization checks are satisfied.|.

    ENDIF.

*--------------------------------------------------------------------
* Overall Status
*
* Rule:
* 1. Activation Error   -> Error
* 2. Activation Warning -> Warning
* 3. Authorization Error/Warning -> Warning
* 4. Otherwise -> Healthy
*--------------------------------------------------------------------

    IF rs_health-act_summary_state = zcl_drj_capability_validator=>gc_error.

      rs_health-overall_status_state = zcl_drj_capability_validator=>gc_error.

      rs_health-overall_status = 'Error'.

    ELSEIF rs_health-act_summary_state = zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status_state = zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status = 'Warning'.

    ELSEIF rs_health-auth_summary_state = zcl_drj_capability_validator=>gc_error
           OR rs_health-auth_summary_state = zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status_state = zcl_drj_capability_validator=>gc_warning.

      rs_health-overall_status = 'Warning'.

    ELSE.

      rs_health-overall_status_state = zcl_drj_capability_validator=>gc_success.

      rs_health-overall_status = 'Healthy'.

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
