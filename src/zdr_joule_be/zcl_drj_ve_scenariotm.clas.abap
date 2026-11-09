CLASS zcl_drj_ve_scenariotm DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_sadl_exit.
    INTERFACES if_sadl_exit_calc_element_read.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_intent,
        semantic_object TYPE sui_tm_mm_app-sem_obj,
        semantic_action TYPE sui_tm_mm_app-sem_act,
      END OF ty_intent.

    TYPES tty_intent TYPE SORTED TABLE OF ty_intent
      WITH UNIQUE KEY semantic_object semantic_action.

    TYPES:
      BEGIN OF ty_fiori_app_info,
        semantic_object         TYPE sui_tm_mm_app-sem_obj,
        semantic_action         TYPE sui_tm_mm_app-sem_act,
        fiori_app_id            TYPE sui_tm_mm_app-fiori_id,
        fiori_app_name          TYPE sui_tm_mm_appt-description,
        fiori_apps_library_link TYPE string,
      END OF ty_fiori_app_info.

    TYPES tty_fiori_app_info TYPE SORTED TABLE OF ty_fiori_app_info
      WITH UNIQUE KEY semantic_object semantic_action.

    TYPES tty_fiori_app_info_raw TYPE STANDARD TABLE OF ty_fiori_app_info
      WITH EMPTY KEY.

    METHODS get_activation_status
      IMPORTING
        iv_semantic_object TYPE string
        iv_semantic_action TYPE string
        iv_catalog_id      TYPE string
      RETURNING
        VALUE(rv_status)   TYPE abap_char1.

    METHODS get_authorization_status
      IMPORTING
        iv_semantic_object TYPE string
        iv_semantic_action TYPE string
      RETURNING
        VALUE(rv_status)   TYPE abap_char1.

    METHODS get_fiori_app_info
      IMPORTING
        it_intents     TYPE tty_intent
      RETURNING
        VALUE(rt_info) TYPE tty_fiori_app_info.

    METHODS build_fal_link
      IMPORTING
        iv_fiori_app_id TYPE string
      RETURNING
        VALUE(rv_link)  TYPE string.

ENDCLASS.



CLASS zcl_drj_ve_scenariotm IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~calculate.

    FIELD-SYMBOLS:
      <ls_original>            TYPE any,
      <ls_calc>                TYPE any,
      <lv_semobj>              TYPE any,
      <lv_semaction>           TYPE any,
      <lv_catalog_id>          TYPE any,
      <lv_act_status>          TYPE any,
      <lv_auth_status>         TYPE any,
      <lv_fiori_app_id_ve>     TYPE any,
      <lv_fiori_app_name>      TYPE any,
      <lv_fiori_apps_lib_link> TYPE any.

    DATA:
      lt_intents        TYPE tty_intent,
      lt_fiori_app_info TYPE tty_fiori_app_info,
      ls_fiori_app_info TYPE ty_fiori_app_info.

*--------------------------------------------------------------------
* Collect unique Semantic Object + Semantic Action pairs
*--------------------------------------------------------------------
    LOOP AT it_original_data ASSIGNING <ls_original>.

      UNASSIGN:
        <lv_semobj>,
        <lv_semaction>.

      ASSIGN COMPONENT 'SEMANTICOBJECT'
        OF STRUCTURE <ls_original>
        TO <lv_semobj>.

      ASSIGN COMPONENT 'SEMANTICACTION'
        OF STRUCTURE <ls_original>
        TO <lv_semaction>.

      IF <lv_semobj> IS ASSIGNED
         AND <lv_semaction> IS ASSIGNED
         AND <lv_semobj> IS NOT INITIAL
         AND <lv_semaction> IS NOT INITIAL.

        INSERT VALUE ty_intent(
          semantic_object = CONV #( <lv_semobj> )
          semantic_action = CONV #( <lv_semaction> )
        ) INTO TABLE lt_intents.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* Read Fiori App info once for all rows in this SADL package
*--------------------------------------------------------------------
    lt_fiori_app_info =
      get_fiori_app_info(
        it_intents = lt_intents ).

*--------------------------------------------------------------------
* Fill calculated fields
*--------------------------------------------------------------------
    LOOP AT it_original_data ASSIGNING <ls_original>.

      READ TABLE ct_calculated_data
        ASSIGNING <ls_calc>
        INDEX sy-tabix.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      UNASSIGN:
          <lv_semobj>,
          <lv_semaction>,
          <lv_catalog_id>,
          <lv_act_status>,
          <lv_auth_status>,
          <lv_fiori_app_id_ve>,
          <lv_fiori_app_name>,
          <lv_fiori_apps_lib_link>.

      ASSIGN COMPONENT 'SEMANTICOBJECT'
        OF STRUCTURE <ls_original>
        TO <lv_semobj>.

      ASSIGN COMPONENT 'SEMANTICACTION'
       OF STRUCTURE <ls_original>
       TO <lv_semaction>.

      ASSIGN COMPONENT 'CATALOGID'
        OF STRUCTURE <ls_original>
        TO <lv_catalog_id>.

      IF <lv_semobj> IS NOT ASSIGNED
         OR <lv_semaction> IS NOT ASSIGNED
         OR <lv_catalog_id> IS NOT ASSIGNED.

        CONTINUE.

      ENDIF.

*--------------------------------------------------------------------
* Activation Status
*--------------------------------------------------------------------
      ASSIGN COMPONENT 'ACTIVATIONSTATUS'
        OF STRUCTURE <ls_calc>
        TO <lv_act_status>.

      IF <lv_act_status> IS ASSIGNED.

        <lv_act_status> =
          get_activation_status(
            iv_semantic_object = CONV #( <lv_semobj> )
            iv_semantic_action = CONV #( <lv_semaction> )
            iv_catalog_id      = CONV string( <lv_catalog_id> ) ).

      ENDIF.

*--------------------------------------------------------------------
* Authorization Status
*--------------------------------------------------------------------
      ASSIGN COMPONENT 'AUTHORIZATIONSTATUS'
        OF STRUCTURE <ls_calc>
        TO <lv_auth_status>.

      IF <lv_auth_status> IS ASSIGNED.

        <lv_auth_status> =
          get_authorization_status(
            iv_semantic_object = CONV #( <lv_semobj> )
            iv_semantic_action = CONV #( <lv_semaction> ) ).

      ENDIF.

*--------------------------------------------------------------------
* Fiori App Info from SUI_TM_MM_APP
*--------------------------------------------------------------------
      CLEAR ls_fiori_app_info.

      READ TABLE lt_fiori_app_info
        INTO ls_fiori_app_info
        WITH TABLE KEY
          semantic_object = CONV #( <lv_semobj> )
          semantic_action = CONV #( <lv_semaction> ).

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT 'FIORIAPPIDVE'
        OF STRUCTURE <ls_calc>
        TO <lv_fiori_app_id_ve>.

      IF <lv_fiori_app_id_ve> IS ASSIGNED.
        <lv_fiori_app_id_ve> = ls_fiori_app_info-fiori_app_id.
      ENDIF.

      ASSIGN COMPONENT 'FIORIAPPNAME'
        OF STRUCTURE <ls_calc>
        TO <lv_fiori_app_name>.

      IF <lv_fiori_app_name> IS ASSIGNED.
        <lv_fiori_app_name> = ls_fiori_app_info-fiori_app_name.
      ENDIF.

      ASSIGN COMPONENT 'FIORIAPPSLIBRARYLINK'
        OF STRUCTURE <ls_calc>
        TO <lv_fiori_apps_lib_link>.

      IF <lv_fiori_apps_lib_link> IS ASSIGNED.
        <lv_fiori_apps_lib_link> =
          ls_fiori_app_info-fiori_apps_library_link.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.



  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

    LOOP AT it_requested_calc_elements
      ASSIGNING FIELD-SYMBOL(<fs_calc_element>).

      CASE <fs_calc_element>.

        WHEN 'ACTIVATIONSTATUS'
          OR 'AUTHORIZATIONSTATUS'
          OR 'FIORIAPPIDVE'
          OR 'FIORIAPPNAME'
          OR 'FIORIAPPSLIBRARYLINK'.

          INSERT CONV string( 'SEMANTICOBJECT' )
            INTO TABLE et_requested_orig_elements.

          INSERT CONV string( 'SEMANTICACTION' )
            INTO TABLE et_requested_orig_elements.

          INSERT CONV string( 'CATALOGID' )
            INTO TABLE et_requested_orig_elements.

      ENDCASE.

    ENDLOOP.

  ENDMETHOD.



  METHOD get_activation_status.

    DATA(ls_tm) =
      zcl_drj_service_checker=>check_target_mapping_act(
        iv_semantic_object = CONV #( iv_semantic_object )
        iv_semantic_action = CONV #( iv_semantic_action )
        iv_catalog_id      = iv_catalog_id ).

    rv_status = ls_tm-status.

  ENDMETHOD.



  METHOD get_authorization_status.

    DATA(ls_auth) =
      zcl_drj_service_checker=>check_target_mapping_auth(
        iv_semantic_object = iv_semantic_object
        iv_semantic_action = iv_semantic_action ).

    rv_status = ls_auth-status.

  ENDMETHOD.

  METHOD get_fiori_app_info.

    DATA lt_raw TYPE tty_fiori_app_info_raw.

    IF it_intents IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Read SUI_TM_MM_APP for SO + Action where Fiori ID is available
* Read description/text from SUI_TM_MM_APPT
*--------------------------------------------------------------------
    SELECT
        app~sem_obj     AS semantic_object,
        app~sem_act     AS semantic_action,
        app~fiori_id    AS fiori_app_id,
        txt~description AS fiori_app_name
      FROM sui_tm_mm_app AS app
      LEFT OUTER JOIN sui_tm_mm_appt AS txt
        ON  txt~app_id = app~app_id
        AND txt~langu  = @sy-langu
      FOR ALL ENTRIES IN @it_intents
      WHERE app~sem_obj  = @it_intents-semantic_object
        AND app~sem_act  = @it_intents-semantic_action
        AND app~fiori_id <> @space
      INTO CORRESPONDING FIELDS OF TABLE @lt_raw.

    IF lt_raw IS INITIAL.
      RETURN.
    ENDIF.

    DELETE lt_raw WHERE fiori_app_id IS INITIAL.

*--------------------------------------------------------------------
* Same SO/Action can theoretically have multiple Fiori IDs.
* Deterministic rule: keep first Fiori ID after sorting.
*
* Description fallback:
* If selected Fiori ID row has no description, use any non-empty
* description found for the same Semantic Object + Action.
*--------------------------------------------------------------------
    SORT lt_raw BY semantic_object semantic_action fiori_app_id.

    LOOP AT lt_raw INTO DATA(ls_raw).

      READ TABLE rt_info
        TRANSPORTING NO FIELDS
        WITH TABLE KEY
          semantic_object = ls_raw-semantic_object
          semantic_action = ls_raw-semantic_action.

      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

*--------------------------------------------------------------------
* Fallback description for same Semantic Object + Action
*--------------------------------------------------------------------
      IF ls_raw-fiori_app_name IS INITIAL.

        LOOP AT lt_raw INTO DATA(ls_desc)
          WHERE semantic_object = ls_raw-semantic_object
            AND semantic_action = ls_raw-semantic_action.

          IF ls_desc-fiori_app_name IS NOT INITIAL.
            ls_raw-fiori_app_name = ls_desc-fiori_app_name.
            EXIT.
          ENDIF.

        ENDLOOP.

      ENDIF.

*--------------------------------------------------------------------
* Build Fiori Apps Library link from selected Fiori ID
*--------------------------------------------------------------------
      ls_raw-fiori_apps_library_link =
        build_fal_link(
          iv_fiori_app_id = CONV string( ls_raw-fiori_app_id ) ).

      INSERT ls_raw INTO TABLE rt_info.

    ENDLOOP.

  ENDMETHOD.

  METHOD build_fal_link.

    DATA(lv_fiori_app_id) = iv_fiori_app_id.

    CONDENSE lv_fiori_app_id NO-GAPS.

    IF lv_fiori_app_id IS INITIAL.
      RETURN.
    ENDIF.

    rv_link =
      |https://fioriappslibrary.hana.ondemand.com/sap/fix/externalViewer/#/detail/Apps('{ lv_fiori_app_id }')|.

  ENDMETHOD.

ENDCLASS.
