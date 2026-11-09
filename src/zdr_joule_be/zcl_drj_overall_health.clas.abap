CLASS zcl_drj_overall_health DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_health,

        health_id                TYPE char20,

        context_user             TYPE syuname,

        overall_status           TYPE string,
        overall_status_state     TYPE char1,

        number_of_apis           TYPE i,
        apis_active              TYPE i,
        apis_authorized          TYPE i,

        number_of_tms            TYPE i,
        tms_active               TYPE i,
        tms_authorized           TYPE i,

        auth_summary             TYPE string,
        auth_summary_description TYPE string,

      END OF ty_health.

    CLASS-METHODS get_overall_health
      IMPORTING
        iv_user          TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_health) TYPE ty_health.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_drj_overall_health IMPLEMENTATION.

  METHOD get_overall_health.

    CLEAR rs_health.

*--------------------------------------------------------------------
* Resolve context user once
*--------------------------------------------------------------------
    DATA(lv_context_user) = COND syuname(
                              WHEN iv_user IS NOT INITIAL
                              THEN iv_user
                              ELSE sy-uname ).

    rs_health-health_id    = 'OVERALL'.
    rs_health-context_user = lv_context_user.

*--------------------------------------------------------------------
* Read APIs
*--------------------------------------------------------------------
    SELECT
      odataservicename,
      apiversion
      FROM zi_drj_scenarioapi
      INTO TABLE @DATA(lt_apis).

    SORT lt_apis BY odataservicename apiversion.

    DELETE ADJACENT DUPLICATES FROM lt_apis
      COMPARING odataservicename apiversion.

    rs_health-number_of_apis = lines( lt_apis ).

*--------------------------------------------------------------------
* Process APIs
*--------------------------------------------------------------------
    LOOP AT lt_apis ASSIGNING FIELD-SYMBOL(<ls_api>).

      CASE <ls_api>-apiversion.

*------------------------------------------------------------------
* OData V2
*------------------------------------------------------------------
        WHEN 'V2'.

          DATA(ls_v2_act) =
            zcl_drj_service_checker=>check_odata_v2_service_act(
              iv_service_name = CONV #( <ls_api>-odataservicename )
            ).

          IF ls_v2_act-gw_active = abap_true
             AND (
                  ls_v2_act-icf_exists = abap_false
                  OR ls_v2_act-icf_active = abap_true
                 ).

            rs_health-apis_active += 1.

          ENDIF.

          DATA(ls_v2_auth) =
            zcl_drj_service_checker=>check_odata_v2_service_auth(
              iv_service_name = CONV #( <ls_api>-odataservicename )
              iv_user         = lv_context_user
            ).

          "Same logic as capability validator:
          "at least one of IWSG/IWSV must be present

          IF ls_v2_auth-iwsg_auth = abap_true
             OR ls_v2_auth-iwsv_auth = abap_true.

            rs_health-apis_authorized += 1.

          ENDIF.

*------------------------------------------------------------------
* OData V4
*------------------------------------------------------------------
        WHEN 'V4'.

          DATA(ls_v4_act) =
            zcl_drj_service_checker=>check_odata_v4_service_act(
              iv_group_id = CONV #( <ls_api>-odataservicename )
            ).

          IF ls_v4_act-gw_active = abap_true.

            rs_health-apis_active += 1.

          ENDIF.

          DATA(ls_v4_auth) =
            zcl_drj_service_checker=>check_odata_v4_service_auth(
              iv_group_id = CONV #( <ls_api>-odataservicename )
              iv_user     = lv_context_user
            ).

          IF ls_v4_auth-service_auth = abap_true.

            rs_health-apis_authorized += 1.

          ENDIF.

      ENDCASE.

    ENDLOOP.

*--------------------------------------------------------------------
* Read Target Mappings
*--------------------------------------------------------------------
    SELECT
      semanticobject,
      semanticaction,
      catalogid
      FROM zi_drj_scenariotargetmapping
      INTO TABLE @DATA(lt_tms).

    SORT lt_tms BY semanticobject
                  semanticaction
                  catalogid.

    DELETE ADJACENT DUPLICATES FROM lt_tms
      COMPARING semanticobject
                semanticaction
                catalogid.

    rs_health-number_of_tms = lines( lt_tms ).

*--------------------------------------------------------------------
* Process Target Mappings
*--------------------------------------------------------------------
    LOOP AT lt_tms ASSIGNING FIELD-SYMBOL(<ls_tm>).

*------------------------------------------------------------------
* Activation
*------------------------------------------------------------------
      DATA(ls_tm_act) =
        zcl_drj_service_checker=>check_target_mapping_act(
          iv_semantic_object = CONV #( <ls_tm>-semanticobject )
          iv_semantic_action = CONV #( <ls_tm>-semanticaction )
          iv_catalog_id      = CONV #( <ls_tm>-catalogid )
          iv_user            = lv_context_user
        ).

      IF ls_tm_act-status = zcl_drj_capability_validator=>gc_success.

        rs_health-tms_active += 1.

      ENDIF.

*------------------------------------------------------------------
* Authorization
*------------------------------------------------------------------
      DATA(ls_tm_auth) =
        zcl_drj_service_checker=>check_target_mapping_auth(
          iv_semantic_object = CONV #( <ls_tm>-semanticobject )
          iv_semantic_action = CONV #( <ls_tm>-semanticaction )
          iv_catalog_id      = CONV #( <ls_tm>-catalogid )
          iv_user            = lv_context_user
        ).

      IF ls_tm_auth-status = zcl_drj_capability_validator=>gc_success.

        rs_health-tms_authorized += 1.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* Determine Overall Status
*--------------------------------------------------------------------
    IF rs_health-apis_active <> rs_health-number_of_apis
       OR rs_health-tms_active <> rs_health-number_of_tms.

      rs_health-overall_status       = 'Error'.
      rs_health-overall_status_state = 'E'.

    ELSEIF rs_health-apis_authorized <> rs_health-number_of_apis
       OR rs_health-tms_authorized <> rs_health-number_of_tms.

      rs_health-overall_status       = 'Warning'.
      rs_health-overall_status_state = 'W'.

    ELSE.

      rs_health-overall_status       = 'Success'.
      rs_health-overall_status_state = 'S'.

    ENDIF.

*--------------------------------------------------------------------
* Authorization Summary
*--------------------------------------------------------------------
    rs_health-auth_summary =
      |APIs { rs_health-apis_authorized }/{ rs_health-number_of_apis }, |
      && |TMs { rs_health-tms_authorized }/{ rs_health-number_of_tms }|.

    rs_health-auth_summary_description =
      |User { lv_context_user } has access to { rs_health-apis_authorized } of { rs_health-number_of_apis } APIs and |
      && | { rs_health-tms_authorized } of { rs_health-number_of_tms } Target Mappings.|.

  ENDMETHOD.

ENDCLASS.
