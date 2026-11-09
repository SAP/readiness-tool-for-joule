CLASS zcl_drj_service_checker DEFINITION PUBLIC FINAL CREATE PUBLIC.

  "====================================================================
  " Service Checker
  "
  " Central technical validation layer for activation and authorization.
  "
  " ACTIVATION
  "
  " ├─ check_odata_v2_service_act
  " │   └─ /ui2/cl_service_info_proxy
  " │       └─ is_odata_v2_service_active
  " │
  " ├─ check_odata_v4_service_act
  " │   └─ /ui2/cl_service_info_proxy
  " │       └─ is_odata_v4_group_published
  " │
  " ├─ check_icf_service_act
  " │   └─ /ui2/cl_service_info_proxy
  " │       └─ is_icf_service_active
  " │
  " └─ check_target_mapping_act
  "     ├─ Catalog validation / TM resolution
  "     │   └─ zcl_drj_flp_start_up_utility
  "     │       ├─ catalog_exists
  "     │       ├─ get_all_tms_for_cat_so_sa
  "     │       ├─ user_assigned_tms_for_so_sa
  "     │       ├─ lookup_all_tms
  "     │       └─ sort_and_compress_tms
  "     │
  "     └─ check_multi_tms_app_act
  "         └─ check_tm_app_act
  "             ├─ TR     → transaction existence
  "             ├─ WDA    → WDA dependency activation
  "             └─ SAPUI5 → ICF + UI5 dependency activation
  "
  " AUTHORIZATION
  "
  " ├─ check_odata_v2_service_auth
  " │   ├─ /iwfnd/i_med_srh + USOBHASH
  " │   └─ AUTHORITY_CHECK → S_SERVICE (IWSG / IWSV)
  " │
  " ├─ check_odata_v4_service_auth
  " │   ├─ /iwfnd/c_v4_msgr
  " │   └─ AUTHORITY_CHECK → S_START / G4BA
  " │
  " ├─ check_icf_service_auth
  " │   └─ currently not applicable / treated as successful
  " │
  " └─ check_target_mapping_auth
  "     ├─ Authorization based on User + Semantic Object + Action
  "     │   └─ Catalog intentionally not used as strict constraint
  "     ├─ zcl_drj_flp_start_up_utility
  "     │   ├─ has_start_up_tm
  "     │   ├─ user_assigned_tms_for_so_sa
  "     │   └─ sort_and_compress_tms
  "     │
  "     └─ check_multi_tms_app_auth
  "         └─ check_tm_app_auth
  "             ├─ TR
  "             │   └─ AUTHORITY_CHECK → S_TCODE
  "             ├─ WDA
  "             │   └─ WDA application authorization
  "             └─ SAPUI5
  "                 ├─ check_icf_service_auth
  "                 └─ check_sapui5_dependencies_auth
  "                     ├─ zcl_drj_fdm_utility
  "                     │   ├─ get_tm_app_info_ui5
  "                     │   └─ get_ui5_comp_dep_details_v2
  "                     └─ check_all_ui5_depend_auth
  "
  " UI5 HELPERS
  "
  " ├─ get_ui5_app_info
  " │   └─ /ui5/cl_ui5_app_index
  " │       └─ get_ui5_app_info
  " │
  " └─ get_ui5_dependencies
  "     └─ get_ui5_app_info
  "====================================================================

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_odata_status,
        gw_active   TYPE abap_bool,
        icf_exists  TYPE abap_bool,
        icf_active  TYPE abap_bool,
        status_text TYPE string,
      END OF ty_odata_status.

    TYPES:
      BEGIN OF ty_icf_status,
        exists      TYPE abap_bool,
        active      TYPE abap_bool,
        subrc       TYPE sysubrc,
        status_text TYPE string,
      END OF ty_icf_status.

    TYPES:
      BEGIN OF ty_tm_status,
        status      TYPE c LENGTH 1,
        status_text TYPE string,
      END OF ty_tm_status.

    CONSTANTS:
      gc_success TYPE c LENGTH 1 VALUE 'S',
      gc_warning TYPE c LENGTH 1 VALUE 'W',
      gc_error   TYPE c LENGTH 1 VALUE 'E'.

    TYPES:
      BEGIN OF ty_tm_authorization_status,
        status      TYPE c LENGTH 1,
        status_text TYPE string,
      END OF ty_tm_authorization_status.

    TYPES:
      BEGIN OF ty_v2_authorization_status,
        service_found TYPE abap_bool,
        iwsg_auth     TYPE abap_bool,
        iwsv_auth     TYPE abap_bool,
        status_text   TYPE string,
      END OF ty_v2_authorization_status.

    TYPES:
      BEGIN OF ty_v4_authorization_status,
        service_published TYPE abap_bool,
        service_auth      TYPE abap_bool,
        status_text       TYPE string,
      END OF ty_v4_authorization_status.

    TYPES:
      BEGIN OF ty_authorization_status,
        success     TYPE abap_bool,
        status_text TYPE string,
      END OF ty_authorization_status.

    TYPES:
      BEGIN OF ty_ui5_dependency,
        dep_type     TYPE string,
        id           TYPE string,
        component_id TYPE string,
        url          TYPE string,
      END OF ty_ui5_dependency.

    TYPES tt_ui5_dependency TYPE STANDARD TABLE OF ty_ui5_dependency
      WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_ui5_dependency_act_detail,
        sequence        TYPE i,
        semantic_object TYPE /ui2/semantic_object,
        semantic_action TYPE /ui2/semantic_action,
        catalog_id      TYPE string,
        component_id    TYPE string,
        dependency_type TYPE string,
        service_name    TYPE string,
        service_version TYPE string,
        url             TYPE string,
        status          TYPE c LENGTH 1,
        success         TYPE abap_bool,
        status_text     TYPE string,
      END OF ty_ui5_dependency_act_detail.

    TYPES tt_ui5_dependency_act_detail
      TYPE STANDARD TABLE OF ty_ui5_dependency_act_detail
      WITH EMPTY KEY.

    CLASS-METHODS check_tm_app_act
      IMPORTING
        is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
      RETURNING
        VALUE(rs_status) TYPE ty_tm_status.

    CLASS-METHODS check_multi_tms_app_act
      IMPORTING
        it_tm            TYPE zcl_drj_flp_start_up_utility=>tty_tm
      RETURNING
        VALUE(rs_status) TYPE ty_tm_status.

    CLASS-METHODS check_odata_v2_service_act
      IMPORTING
        iv_service_name  TYPE /iwfnd/med_mdl_srg_name
        iv_version       TYPE /iwfnd/med_mdl_version DEFAULT 1
      RETURNING
        VALUE(rs_status) TYPE ty_odata_status.

    CLASS-METHODS check_odata_v4_service_act
      IMPORTING
        iv_group_id      TYPE /iwfnd/v4_med_group_id
      RETURNING
        VALUE(rs_status) TYPE ty_odata_status.

    CLASS-METHODS check_target_mapping_act
      IMPORTING
        iv_semantic_object TYPE /ui2/fdm_semantic_object
        iv_semantic_action TYPE /ui2/fdm_semantic_action
        iv_catalog_id      TYPE string OPTIONAL
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_status)   TYPE ty_tm_status.
    " Activation is not user based, but we do it like that to save efforts pulling TMS
    " If no CAT is supplied, we would respect users TMs first to be more efficient

    CLASS-METHODS check_tm_app_auth
      IMPORTING
        is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
        iv_user          TYPE syuname OPTIONAL
      RETURNING
        VALUE(rs_status) TYPE ty_tm_authorization_status.

    CLASS-METHODS check_multi_tms_app_auth
      IMPORTING
        it_tm            TYPE zcl_drj_flp_start_up_utility=>tty_tm
        iv_user          TYPE syuname OPTIONAL
      RETURNING
        VALUE(rs_status) TYPE ty_tm_authorization_status.

    CLASS-METHODS check_icf_service_act
      IMPORTING
        iv_url           TYPE string
      RETURNING
        VALUE(rs_status) TYPE ty_icf_status.

    CLASS-METHODS check_odata_v2_service_auth
      IMPORTING
        iv_service_name  TYPE /iwfnd/med_mdl_service_grp_id
        iv_version       TYPE /iwfnd/med_mdl_version DEFAULT 1
        iv_user          TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_status) TYPE ty_v2_authorization_status.

    CLASS-METHODS check_odata_v4_service_auth
      IMPORTING
        iv_group_id      TYPE /iwfnd/v4_med_group_id
        iv_user          TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_status) TYPE ty_v4_authorization_status.

    CLASS-METHODS check_target_mapping_auth
      IMPORTING
        iv_semantic_object TYPE string
        iv_semantic_action TYPE string
        iv_catalog_id      TYPE string OPTIONAL
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_status)   TYPE ty_tm_authorization_status.


    CLASS-METHODS check_icf_service_auth
      IMPORTING
        iv_url           TYPE string
        iv_user          TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_status) TYPE ty_authorization_status.

    CLASS-METHODS check_ui5_dep_act_detail
      IMPORTING
        is_dependency    TYPE zcl_drj_fdm_utility=>ty_dependency_formatter_v2
      RETURNING
        VALUE(rs_result) TYPE ty_ui5_dependency_act_detail.

    CLASS-METHODS get_ui5_dep_act_details
      IMPORTING
        iv_semantic_object TYPE /ui2/semantic_object
        iv_semantic_action TYPE /ui2/semantic_action
        iv_catalog_id      TYPE string OPTIONAL
        iv_user            TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rt_result)   TYPE tt_ui5_dependency_act_detail.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA mo_proxy TYPE REF TO /ui2/if_service_info_proxy.

    CLASS-METHODS get_single_ui5_app_info
      IMPORTING
        it_component   TYPE /ui5/app_index_component_id
      RETURNING
        VALUE(rt_info) TYPE /ui5/app_index_ui5_info_t.

    CLASS-METHODS get_ui5_app_info
      IMPORTING
        it_components  TYPE /ui5/app_index_component_id_t
      RETURNING
        VALUE(rt_info) TYPE /ui5/app_index_ui5_info_t.

    CLASS-METHODS get_ui5_dependencies
      IMPORTING
        it_components TYPE /ui5/app_index_component_id_t
      RETURNING
        VALUE(rt_dep) TYPE tt_ui5_dependency.

    CLASS-METHODS check_tr_app_auth
      IMPORTING
        is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
        iv_user          TYPE syuname OPTIONAL
      RETURNING
        VALUE(rs_status) TYPE ty_tm_authorization_status.

    CLASS-METHODS check_wda_app_auth
      IMPORTING
        is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
        iv_user          TYPE syuname OPTIONAL
      RETURNING
        VALUE(rs_status) TYPE ty_tm_authorization_status.

    CLASS-METHODS check_sapui5_app_auth
      IMPORTING
        is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
        iv_user          TYPE syuname OPTIONAL
      RETURNING
        VALUE(rs_status) TYPE ty_tm_authorization_status.

    CLASS-METHODS check_sapui5_dependencies_auth
      IMPORTING
        is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
        iv_user          TYPE syuname OPTIONAL
      RETURNING
        VALUE(rs_status) TYPE ty_tm_authorization_status.

    CLASS-METHODS check_ui5_dependency_act
      IMPORTING
        is_dependency    TYPE zcl_drj_fdm_utility=>ty_dependency_formatter_v2
      RETURNING
        VALUE(rs_status) TYPE ty_authorization_status.

  CLASS-METHODS check_sapui5_dependencies_act
    IMPORTING
      is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
    RETURNING
      VALUE(rs_status) TYPE ty_tm_status.


  CLASS-METHODS check_sapui5_dep_act_fast
    IMPORTING
      is_tm            TYPE zcl_drj_flp_start_up_utility=>ty_tm
    RETURNING
      VALUE(rs_status) TYPE ty_tm_status.


  CLASS-METHODS check_all_ui5_depend_act
    IMPORTING
      it_dependency    TYPE zcl_drj_fdm_utility=>tt_dependency_formatter_v2
      RETURNING
        VALUE(rs_status) TYPE ty_authorization_status.

    CLASS-METHODS check_ui5_dependency_auth
      IMPORTING
        is_dependency    TYPE zcl_drj_fdm_utility=>ty_dependency_formatter_v2
        iv_user          TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_status) TYPE ty_authorization_status.

    CLASS-METHODS check_all_ui5_depend_auth
      IMPORTING
        it_dependency    TYPE zcl_drj_fdm_utility=>tt_dependency_formatter_v2
        iv_user          TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rs_status) TYPE ty_authorization_status.

    CLASS-METHODS check_all_wda_depend_act
      IMPORTING
        it_services      TYPE /ui2/cl_service_info=>tt_service
      RETURNING
        VALUE(rs_status) TYPE ty_tm_status.

ENDCLASS.



CLASS zcl_drj_service_checker IMPLEMENTATION.


  METHOD check_tm_app_act.

    CASE is_tm-application_type.

*--------------------------------------------------------------------
* Transaction
*--------------------------------------------------------------------
      WHEN 'TR'.

        DATA(lv_tcode) =
          is_tm-application-tra-code.

        IF lv_tcode IS INITIAL.

          rs_status-status = gc_error.

          rs_status-status_text =
            'No transaction code maintained in Target Mapping'.

          RETURN.

        ENDIF.

        SELECT SINGLE tcode
          FROM tstc
          INTO @DATA(lv_dummy_tcode)
          WHERE tcode = @lv_tcode.

        IF sy-subrc = 0.

          rs_status-status = gc_success.

          rs_status-status_text =
            |Transaction { lv_tcode } exists|.

        ELSE.

          rs_status-status = gc_error.

          rs_status-status_text =
            |Transaction { lv_tcode } does not exist|.

        ENDIF.

*--------------------------------------------------------------------
* Web Dynpro
*--------------------------------------------------------------------
      WHEN 'WDA'.

*------------------------------------------------------------------
* Resolve WDA Dependency
*------------------------------------------------------------------
        DATA(ls_tm_info) = zcl_drj_fdm_utility=>get_tm_app_info_wda(
            iv_catalog_id      = is_tm-catalog_id
            iv_semantic_object = is_tm-object
            iv_semantic_action = is_tm-action ).

        IF ls_tm_info-found = abap_false.

          rs_status-status = gc_error.

          rs_status-status_text = 'Unable to resolve TM application information'.

          RETURN.

        ENDIF.

        DATA: ls_fdm_tm TYPE /ui2/if_fdm=>ts_tm.

        ls_fdm_tm-application-type = ls_tm_info-application-type.

        ls_fdm_tm-application-target-wda = ls_tm_info-application-target-wda.

        DATA(lt_wda_services) =
          zcl_drj_fdm_utility=>get_single_tm_wda_dependencies(
            it_target_mapping = ls_fdm_tm ).

        DATA(ls_wda_dep_status) = check_all_wda_depend_act( it_services = lt_wda_services ).

*--------------------------------------------------------------------
* WDA Experiment Results
*
* 0 dependencies = broken TM
* 1 dependency   = expected
* >1 dependency  = unexpected
*--------------------------------------------------------------------
        IF lt_wda_services IS INITIAL.

          rs_status-status = gc_error.

          rs_status-status_text =
            'No WDA dependency found'.

          RETURN.

        ENDIF.

        IF lines( lt_wda_services ) > 1.

          rs_status-status = gc_warning.

          rs_status-status_text =
            |Unexpected WDA dependency count: { lines( lt_wda_services ) }|.

          RETURN.

        ENDIF.

        rs_status = ls_wda_dep_status.

*--------------------------------------------------------------------
* SAPUI5
*--------------------------------------------------------------------
      WHEN 'SAPUI5'.

*--------------------------------------------------------------------
* Main Application ICF
*--------------------------------------------------------------------
        DATA(lv_uri) =  is_tm-application-sapui5-uri.

        DATA(lv_component) =  is_tm-application-sapui5-component.

        IF lv_uri IS INITIAL AND lv_component IS INITIAL.

          rs_status-status = gc_error.

          rs_status-status_text =
            'No SAPUI5 URI or Component maintained in Target Mapping'.

          RETURN.

        ENDIF.

*--------------------------------------------------------------------
* Either of URL or Component is maintained.
*--------------------------------------------------------------------
        IF lv_uri IS NOT INITIAL.

          DATA(ls_icf_status) =
            check_icf_service_act(
              iv_url = lv_uri ).

          IF ls_icf_status-active <> abap_true.

            rs_status-status = gc_error.

            rs_status-status_text =
              |SAPUI5 application ICF inactive: { lv_uri }|.

            RETURN.

          ENDIF.
        ELSEIF lv_component IS NOT INITIAL.
          "Dependencies would take care of self component.
      ENDIF.

*--------------------------------------------------------------------
* Dependency Validation
*--------------------------------------------------------------------
      DATA(ls_deep_act) =
        check_sapui5_dep_act_fast(
          is_tm = is_tm ).


*--------------------------------------------------------------------
* Dependency result drives outcome
*--------------------------------------------------------------------
      IF ls_deep_act-status <> gc_success.

          rs_status = ls_deep_act.

          RETURN.

        ENDIF.

*--------------------------------------------------------------------
* Success
*--------------------------------------------------------------------
        rs_status-status = gc_success.

        rs_status-status_text =
          |SAPUI5 application active including dependencies|.

*--------------------------------------------------------------------
* Other Types
*--------------------------------------------------------------------
      WHEN OTHERS.

        rs_status-status = gc_success.

        rs_status-status_text =
          |Unsupported application type { is_tm-application_type }|.

    ENDCASE.

  ENDMETHOD.

  METHOD check_multi_tms_app_act.

    DATA(lv_warning_found) = abap_false.

*--------------------------------------------------------------------
* No TMs supplied
*--------------------------------------------------------------------
    IF it_tm IS INITIAL.

      rs_status-status = gc_success.

      rs_status-status_text =
        'No Target Mappings supplied'.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Check all TMs
*--------------------------------------------------------------------
    LOOP AT it_tm ASSIGNING FIELD-SYMBOL(<ls_tm>).

      DATA(ls_tm_status) =
        check_tm_app_act(
          is_tm = <ls_tm> ).

*--------------------------------------------------------------------
* First Error wins
*--------------------------------------------------------------------
      IF ls_tm_status-status = gc_error.

        rs_status = ls_tm_status.

        RETURN.

      ENDIF.

*--------------------------------------------------------------------
* Remember warnings
*--------------------------------------------------------------------
      IF ls_tm_status-status = gc_warning.

        lv_warning_found = abap_true.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* Final Result
*--------------------------------------------------------------------
    IF lv_warning_found = abap_true.

      rs_status-status = gc_warning.

      rs_status-status_text =
        |One or more of the { lines( it_tm ) } Target Mappings returned warnings|.

    ELSE.

      rs_status-status = gc_success.

      rs_status-status_text =
        |All { lines( it_tm ) } Target Mappings passed activation validation|.

    ENDIF.

  ENDMETHOD.

  METHOD check_odata_v2_service_act.
    TRY.
        mo_proxy = NEW /ui2/cl_service_info_proxy( ).

        mo_proxy->is_odata_v2_service_active(
          EXPORTING
            iv_service_name       = iv_service_name
            iv_service_version    = iv_version
          IMPORTING
            ev_is_active          = rs_status-gw_active
            ev_icf_node_exists    = rs_status-icf_exists
            ev_icf_node_is_active = rs_status-icf_active
        ).

        rs_status-status_text = COND #(
          WHEN rs_status-gw_active = abap_false
          THEN 'OData service inactive or does not exist'
          WHEN rs_status-icf_exists = abap_false
          THEN 'Node opu/odata is used and active (Note 3383515)'
          WHEN rs_status-icf_active = abap_true
          THEN 'Specific ICF node is active'
          ELSE 'Specific ICF node is inactive'
        ).

      CATCH /iwfnd/cx_med_remote
            /iwfnd/cx_cof
            cx_root INTO DATA(lx).

        rs_status-status_text = lx->get_text( ).

    ENDTRY.

  ENDMETHOD.

  METHOD check_odata_v4_service_act.

    TRY.

        mo_proxy = NEW /ui2/cl_service_info_proxy( ).

        rs_status-gw_active =
          mo_proxy->is_odata_v4_group_published(
            iv_group_id = iv_group_id ).

        IF rs_status-gw_active = abap_true.

          rs_status-status_text =
            'OData V4 service group is published'.

        ELSE.

          rs_status-status_text =
            'OData V4 service group is not published'.

        ENDIF.

      CATCH /iwfnd/cx_gateway
            cx_root INTO DATA(lx).

        rs_status-gw_active = abap_false.
        rs_status-status_text = lx->get_text( ).

    ENDTRY.

  ENDMETHOD.

  METHOD check_target_mapping_act.

    DATA lt_tm TYPE zcl_drj_flp_start_up_utility=>tty_tm.

    DATA lv_can_sort_compress TYPE abap_bool.

    DATA lv_effective_catalog_id TYPE /ui2/page_id.

    CLEAR lv_can_sort_compress.

    lv_effective_catalog_id =
      CONV /ui2/page_id( iv_catalog_id ).

*--------------------------------------------------------------------
* Validate configured catalog against this system and intent
*
* A supplied catalog is used only when:
*   1. the catalog exists locally, and
*   2. it contains the configured Semantic Object + Action.
*
* Otherwise treat it exactly like no catalog was supplied and use
* the existing SO/SA fallback.
*--------------------------------------------------------------------
    IF lv_effective_catalog_id IS NOT INITIAL.

      IF zcl_drj_flp_start_up_utility=>catalog_exists(
           iv_catalog_id = lv_effective_catalog_id ) = abap_false.

        CLEAR lv_effective_catalog_id.

      ELSEIF zcl_drj_flp_start_up_utility=>tm_exists_in_catalog(
               iv_catalog_id      = lv_effective_catalog_id
               iv_semantic_object = CONV /ui2/semantic_object( iv_semantic_object )
               iv_semantic_action = CONV /ui2/semantic_action( iv_semantic_action ) ) = abap_false.

        CLEAR lv_effective_catalog_id.

      ENDIF.

    ENDIF.

*--------------------------------------------------------------------
* Valid local catalog supplied
*
* Important:
* This is a catalog-filtered subset.
* Do NOT call SORT_AND_COMPRESS_TMS for this result.
*--------------------------------------------------------------------
    IF lv_effective_catalog_id IS NOT INITIAL.

      lt_tm =
        zcl_drj_flp_start_up_utility=>get_all_tms_for_cat_so_sa(
          iv_catalog_id = lv_effective_catalog_id
          iv_object     = CONV /ui2/semantic_object( iv_semantic_object )
          iv_action     = CONV /ui2/semantic_action( iv_semantic_action ) ).

      lv_can_sort_compress = abap_false.

*--------------------------------------------------------------------
* No catalog supplied
*--------------------------------------------------------------------
    ELSE.

*------------------------------------------------------------------
* If a user was supplied, first try user's assigned startup TMs.
*
* Important:
* This is also a subset, not the full SO/SA universe.
* Do NOT call SORT_AND_COMPRESS_TMS for this result.
*------------------------------------------------------------------
      IF iv_user IS NOT INITIAL.

        lt_tm =
          zcl_drj_flp_start_up_utility=>user_assigned_tms_for_so_sa(
            iv_user   = iv_user
            iv_object = CONV /ui2/semantic_object( iv_semantic_object )
            iv_action = CONV /ui2/semantic_action( iv_semantic_action ) ).

        lv_can_sort_compress = abap_false.

      ENDIF.

*------------------------------------------------------------------
* If no user-specific TMs were found, read the full SO/SA universe.
*
* This is the only safe place to use SORT_AND_COMPRESS_TMS.
*------------------------------------------------------------------
      IF lt_tm IS INITIAL.

        lt_tm =
          zcl_drj_flp_start_up_utility=>lookup_all_tms(
            iv_object = CONV /ui2/semantic_object( iv_semantic_object )
            iv_action = CONV /ui2/semantic_action( iv_semantic_action ) ).

        lv_can_sort_compress = abap_true.

      ENDIF.

    ENDIF.

*--------------------------------------------------------------------
* No TMs found
*--------------------------------------------------------------------
    IF lt_tm IS INITIAL.

      rs_status-status = gc_error.

      rs_status-status_text =
        |No Target Mappings found for { iv_semantic_object }-{ iv_semantic_action }|.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Minimize only if the input is the full SO/SA universe
*--------------------------------------------------------------------
    IF lv_can_sort_compress = abap_true.

      lt_tm =
        zcl_drj_flp_start_up_utility=>sort_and_compress_tms(
          it_tm = lt_tm ).

    ENDIF.

*--------------------------------------------------------------------
* Validate all remaining TMs
*--------------------------------------------------------------------
    rs_status =
      check_multi_tms_app_act(
        it_tm = lt_tm ).

  ENDMETHOD.

  METHOD check_icf_service_act.

    DATA lo_proxy TYPE REF TO /ui2/if_service_info_proxy.
    DATA lv_url TYPE string.

    CREATE OBJECT lo_proxy TYPE /ui2/cl_service_info_proxy.

    " Copy the original URL
    lv_url = iv_url.

    " Remove leading and trailing spaces
    CONDENSE lv_url.

    " Remove the unexpected ICF Path prefix, if present
    IF lv_url CP 'ICF Path *'.
      REPLACE FIRST OCCURRENCE OF
        'ICF Path ' IN lv_url WITH ''.
    ENDIF.

    " Ensure no leading or trailing spaces remain
    SHIFT lv_url LEFT DELETING LEADING space.
    SHIFT lv_url RIGHT DELETING TRAILING space.

    TRY.

        lo_proxy->is_icf_service_active(
          EXPORTING
            iv_url      = lv_url
          IMPORTING
            ev_active   = rs_status-active
            ev_sysubrc  = rs_status-subrc ).

        " Determine existence from SY-SUBRC returned by SAP

        IF rs_status-subrc = 1.

          rs_status-exists = abap_false.
          rs_status-active = abap_false.

          rs_status-status_text =
            'ICF service does not exist'.

        ELSE.

          rs_status-exists = abap_true.

          IF rs_status-active = abap_true.

            rs_status-status_text =
              'ICF node is active'.

          ELSE.

            rs_status-status_text =
              'ICF node is inactive'.

          ENDIF.

        ENDIF.

      CATCH cx_root INTO DATA(lx).

        rs_status-status_text = lx->get_text( ).

    ENDTRY.

  ENDMETHOD.


  METHOD check_odata_v2_service_auth.

    DATA:
      ls_srh          TYPE /iwfnd/i_med_srh,
      ls_hash         TYPE usobhash,
      lv_namespace    TYPE /iwfnd/med_mdl_namespace,
      lv_service_name TYPE /iwfnd/med_mdl_service_grp_id,
      lv_iwsv_name    TYPE usobhash-obj_name,
      lv_version      TYPE char4,
      lv_off          TYPE i.

    CLEAR rs_status.

    "---------------------------------------------------------------
    " Parse service input
    "
    " Examples:
    "
    " /IWPGW/TASKPROCESSING
    "   -> Namespace    = /IWPGW/
    "   -> Service Name = TASKPROCESSING
    "
    " API_BUSINESSAREA_SRV
    "   -> Namespace    = ''
    "   -> Service Name = API_BUSINESSAREA_SRV
    "---------------------------------------------------------------

    DATA:
   lt_parts TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    IF iv_service_name CP '/*/*'.

      SPLIT iv_service_name AT '/' INTO TABLE lt_parts.

      "Example:
      "/IWPGW/TASKPROCESSING
      "
      "lt_parts[1] = ''
      "lt_parts[2] = 'IWPGW'
      "lt_parts[3] = 'TASKPROCESSING'

      IF lines( lt_parts ) >= 3.

        lv_namespace =
          '/' &&
          lt_parts[ 2 ] &&
          '/'.

        lv_service_name =
          lt_parts[ 3 ].

      ENDIF.

    ELSE.

      lv_service_name = iv_service_name.

    ENDIF.

    "---------------------------------------------------------------
    " Read service registration
    "---------------------------------------------------------------
    " TODO : later change the db fetch condition to include the latest version, standard reads 0001 so we are going with it

    IF lv_namespace IS INITIAL.

      SELECT SINGLE *
        FROM /iwfnd/i_med_srh
        INTO @ls_srh
        WHERE service_name    = @lv_service_name
          AND service_version = @iv_version.

    ELSE.

      SELECT SINGLE *
        FROM /iwfnd/i_med_srh
        INTO @ls_srh
        WHERE namespace       = @lv_namespace
          AND service_name    = @lv_service_name
          AND service_version = @iv_version.

    ENDIF.

    IF sy-subrc <> 0.

      rs_status-service_found = abap_false.
      rs_status-iwsg_auth     = abap_false.
      rs_status-iwsv_auth     = abap_false.
      rs_status-status_text   = 'Service not found in /IWFND/I_MED_SRH'.

      RETURN.

    ENDIF.

    rs_status-service_found = abap_true.

    "---------------------------------------------------------------
    " IWSG authorization
    "---------------------------------------------------------------

    CLEAR ls_hash.

    SELECT SINGLE *
      FROM usobhash
      INTO @ls_hash
        WHERE object   = 'IWSG'
        AND obj_name = @ls_srh-srv_identifier.

    IF sy-subrc = 0.

      CALL FUNCTION 'AUTHORITY_CHECK'
        EXPORTING
          user                = iv_user
          object              = 'S_SERVICE'
          field1              = 'SRV_NAME'
          value1              = CONV ust12-von( ls_hash-name )
        EXCEPTIONS
          user_dont_exist     = 1
          user_is_authorized  = 2
          user_not_authorized = 3
          user_is_locked      = 4
          OTHERS              = 5.

      IF sy-subrc = 2.
        rs_status-iwsg_auth = abap_true.
      ELSE.
        rs_status-iwsg_auth = abap_false.
      ENDIF.

    ENDIF.

    "---------------------------------------------------------------
    " IWSV authorization
    "
    " Format:
    " <NAMESPACE><SERVICE_NAME>.....<VERSION>
    "
    " Example:
    " /IWPGW/TASKPROCESSING              0002
    "---------------------------------------------------------------

    CLEAR:
      lv_iwsv_name,
      lv_version,
      ls_hash.

    lv_iwsv_name =
      ls_srh-namespace &&
      ls_srh-service_name.

    lv_version =
      |{ ls_srh-service_version WIDTH = 4 PAD = '0' }|.

    lv_iwsv_name+35(4) = lv_version.

    SELECT SINGLE *
      FROM usobhash
      INTO @ls_hash
      WHERE object   = 'IWSV'
        AND obj_name = @lv_iwsv_name.

    IF sy-subrc = 0.

      CALL FUNCTION 'AUTHORITY_CHECK'
        EXPORTING
          user                = iv_user
          object              = 'S_SERVICE'
          field1              = 'SRV_NAME'
          value1              = CONV ust12-von( ls_hash-name )
        EXCEPTIONS
          user_dont_exist     = 1
          user_is_authorized  = 2
          user_not_authorized = 3
          user_is_locked      = 4
          OTHERS              = 5.

      IF sy-subrc = 2.
        rs_status-iwsv_auth = abap_true.
      ELSE.
        rs_status-iwsv_auth = abap_false.
      ENDIF.

    ENDIF.

    rs_status-status_text =
      |Service Found={ rs_status-service_found } IWSG={ rs_status-iwsg_auth } IWSV={ rs_status-iwsv_auth }|.

  ENDMETHOD.

  METHOD check_odata_v4_service_auth.

    DATA ls_msgr TYPE /iwfnd/c_v4_msgr.

    CLEAR rs_status.

    "---------------------------------------------------------------
    " Check whether service group is published
    "---------------------------------------------------------------

    SELECT SINGLE *
      FROM /iwfnd/c_v4_msgr
      INTO @ls_msgr
      WHERE group_id = @iv_group_id.

    IF sy-subrc <> 0.

      rs_status-service_published = abap_false.
      rs_status-service_auth      = abap_false.
      rs_status-status_text       =
        'Service Group not published'.

      RETURN.

    ENDIF.

    rs_status-service_published = abap_true.

    "---------------------------------------------------------------
    " Check S_START authorization
    "
    " AUTHPGMID  = R3TR
    " AUTHOBJTYP = G4BA
    " AUTHOBJNAM = <GROUP_ID>
    "---------------------------------------------------------------

    CALL FUNCTION 'AUTHORITY_CHECK'
      EXPORTING
        user                = iv_user
        object              = 'S_START'
        field1              = 'AUTHPGMID'
        value1              = 'R3TR'
        field2              = 'AUTHOBJTYP'
        value2              = 'G4BA'
        field3              = 'AUTHOBJNAM'
        value3              = CONV ust12-von( iv_group_id )
      EXCEPTIONS
        user_dont_exist     = 1
        user_is_authorized  = 2
        user_not_authorized = 3
        user_is_locked      = 4
        OTHERS              = 5.

    IF sy-subrc = 2.

      rs_status-service_auth = abap_true.

    ELSE.

      rs_status-service_auth = abap_false.

    ENDIF.

    rs_status-status_text =
      |Published={ rs_status-service_published } Auth={ rs_status-service_auth }|.

  ENDMETHOD.

  METHOD check_target_mapping_auth.

    "Authorization is evaluated for the user's available Target Mapping
    "using Semantic Object + Semantic Action.
    "Catalog is intentionally not used as a strict authorization constraint.
    "TODO: Revisit catalog-specific authorization if Joule requires it in future.
    "TODO: Validate if additional dependency-wise authorization checks are required.

    DATA lv_effective_catalog_id TYPE /ui2/page_id.

    lv_effective_catalog_id =
      CONV /ui2/page_id( iv_catalog_id ).

*--------------------------------------------------------------------
* Authorization scope
*
* Catalog is intentionally NOT used as a strict authorization
* constraint for now. Joule resolves the Target Mapping intent by
* Semantic Object + Semantic Action. A customer may also provide the
* same intent through a custom catalog without referring to the
* configured SAP catalog.
*
* Keep the supplied catalog available in lv_effective_catalog_id for
* diagnostics/future strict validation, but do not use it to restrict
* the authorization result.
*--------------------------------------------------------------------
    CLEAR lv_effective_catalog_id.

*--------------------------------------------------------------------
* Catalog-specific authorization intentionally not enforced
*
* Previous strict logic validated:
*
*   User + Catalog + Semantic Object + Semantic Action
*
* using CATALOG_EXISTS and HAS_TM_INDIRECT_CATALOG.
*
* This is intentionally disabled for now because the same intent may
* be provided by a customer-defined Target Mapping in another custom
* catalog. Joule authorization is therefore evaluated using the
* user's available Semantic Object + Semantic Action Target Mappings.
*
* iv_catalog_id remains part of the method contract so that strict
* catalog-aware authorization can be restored later if required.
*--------------------------------------------------------------------


*--------------------------------------------------------------------
* User has any startup TM for SO/Action?
*--------------------------------------------------------------------
    IF zcl_drj_flp_start_up_utility=>has_start_up_tm(
         iv_user            = iv_user
         iv_semantic_object = CONV /ui2/semantic_object( iv_semantic_object )
         iv_semantic_action = CONV /ui2/semantic_action( iv_semantic_action ) ) = abap_false.

      rs_status-status = gc_error.

      rs_status-status_text =
        |User { iv_user } is NOT authorized for any Target Mapping { iv_semantic_object }-{ iv_semantic_action }|.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Read all assigned TMs for user + intent
*--------------------------------------------------------------------
    DATA(lt_tm) =
      zcl_drj_flp_start_up_utility=>user_assigned_tms_for_so_sa(
        iv_user   = iv_user
        iv_object = CONV /ui2/semantic_object( iv_semantic_object )
        iv_action = CONV /ui2/semantic_action( iv_semantic_action ) ).

*--------------------------------------------------------------------
* No TMs found
*--------------------------------------------------------------------
    IF lt_tm IS INITIAL.

      rs_status-status = gc_error.

      rs_status-status_text =
        |No Target Mappings found for { iv_semantic_object }-{ iv_semantic_action }|.

      RETURN.

    ELSE.

*--------------------------------------------------------------------
* TMs found, we can minimize them
*--------------------------------------------------------------------
      lt_tm = zcl_drj_flp_start_up_utility=>sort_and_compress_tms( it_tm = lt_tm ).

    ENDIF.


*--------------------------------------------------------------------
* Evaluate application authorization
*--------------------------------------------------------------------
    rs_status =
      check_multi_tms_app_auth(
        it_tm    = lt_tm
        iv_user  = iv_user ).

    ""TODO Basic start_up check is done, now if you want to do checks related some authority check

  ENDMETHOD.

  METHOD check_icf_service_auth.

    "There is no separate meaningful ICF node authorization check
    "for our validation scope.
    "If the application/service authorization checks pass, ICF auth is
    "considered not applicable and therefore successful.

    rs_status-success = abap_true.

    rs_status-status_text =
      'ICF node authorization check not applicable; assumed successful'.

  ENDMETHOD.

  METHOD get_single_ui5_app_info.
    "This method fetches app info from component info
    DATA lo_app_index TYPE REF TO /ui5/if_ui5_app_index.
    DATA lt_components TYPE /ui5/app_index_component_id_t.
    lt_components = VALUE #( ( it_component ) ).

    lo_app_index = /ui5/cl_ui5_app_index=>get_instance( ).

    lo_app_index->get_ui5_app_info(
      EXPORTING
        it_components = lt_components
      IMPORTING
        et_info       = rt_info ).

  ENDMETHOD.

  METHOD get_ui5_app_info.
    "This method fetches app info from component info
    DATA lo_app_index TYPE REF TO /ui5/if_ui5_app_index.

    lo_app_index = /ui5/cl_ui5_app_index=>get_instance( ).

    lo_app_index->get_ui5_app_info(
      EXPORTING
        it_components = it_components
      IMPORTING
        et_info       = rt_info ).

  ENDMETHOD.

  METHOD get_ui5_dependencies.
    DATA lt_info TYPE /ui5/app_index_ui5_info_t.

    lt_info = get_ui5_app_info(
                it_components = it_components ).

    LOOP AT lt_info INTO DATA(ls_info).

      LOOP AT ls_info-dependencies INTO DATA(ls_dep).

        APPEND VALUE ty_ui5_dependency(
          dep_type     = ls_dep-type
          id           = ls_dep-id
          component_id = ls_dep-component_id
          url          = ls_dep-url
        ) TO rt_dep.

      ENDLOOP.

    ENDLOOP.
  ENDMETHOD.

  METHOD check_tm_app_auth.
    DATA(lv_user) = COND syuname(
                    WHEN iv_user IS NOT INITIAL
                    THEN iv_user
                    ELSE sy-uname ).

    CASE is_tm-application_type.

      WHEN 'TR'.

        rs_status =
          check_tr_app_auth(
            is_tm   = is_tm
            iv_user = lv_user ).

      WHEN 'WDA'.

        rs_status =
         check_wda_app_auth(
            is_tm   = is_tm
            iv_user = lv_user ).

      WHEN 'SAPUI5'.

        rs_status =
          check_sapui5_app_auth(
            is_tm   = is_tm
            iv_user = lv_user ).

      WHEN 'WEBCUIF'.

        rs_status-status = gc_success.

        rs_status-status_text =
          'WEBCUIF authorization validation not implemented yet'.

      WHEN OTHERS.

        rs_status-status = gc_success. "We cant check auths of other types like URL and URLT

        rs_status-status_text =
          |Unsupported application type { is_tm-application_type }|.

    ENDCASE.
  ENDMETHOD.

  METHOD check_sapui5_app_auth.

    DATA(lv_user) = COND syuname(
                      WHEN iv_user IS NOT INITIAL
                      THEN iv_user
                      ELSE sy-uname ).

    DATA(lv_component) = is_tm-application-sapui5-component.

    DATA(lv_uri) = is_tm-application-sapui5-uri.

*--------------------------------------------------------------------
* No component maintained
*--------------------------------------------------------------------
    IF lv_component IS INITIAL.

      rs_status-status = gc_success.

      rs_status-status_text = 'No SAPUI5 component found in Target Mapping'.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* No URI maintained
*--------------------------------------------------------------------
    IF lv_uri IS INITIAL.

      rs_status-status = gc_success.

      rs_status-status_text =
        |SAPUI5 component { lv_component } found for user { lv_user }. No URI maintained.|.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Check ICF Service for activation / TODO check if this needs to be replaced by some auth check
*--------------------------------------------------------------------
*--------------------------------------------------------------------
* TODO:
* Main SAPUI5 application authorization validation not implemented.
* Currently this method only validates dependency authorizations.
* Once check_icf_service_auth is implemented this becomes Level 2 auth check.
*--------------------------------------------------------------------

    DATA(ls_icf_status) =
      check_icf_service_auth(
        iv_url = lv_uri ).

    rs_status-status = gc_success.

*--------------------------------------------------------------------
* Status Text
*--------------------------------------------------------------------
    IF ls_icf_status-success = abap_false.

      rs_status-status = gc_error.

      rs_status-status_text =
        |SAPUI5 component { lv_component } found but ICF service authentication is missing for : { lv_uri }.|.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Main application passed
*--------------------------------------------------------------------
    DATA(ls_deep_auth) =
      check_sapui5_dependencies_auth(
        is_tm   = is_tm
        iv_user = lv_user ).

*--------------------------------------------------------------------
* Dependency result drives final outcome
*--------------------------------------------------------------------
    IF ls_deep_auth-status = gc_warning.

      rs_status = ls_deep_auth.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Success
*--------------------------------------------------------------------
    rs_status-status = gc_success.

    rs_status-status_text =
      |SAPUI5 component { lv_component } authorized including dependencies|.

  ENDMETHOD.

  METHOD check_sapui5_dependencies_auth.

    DATA(lv_user) = COND syuname(
                      WHEN iv_user IS NOT INITIAL
                      THEN iv_user
                      ELSE sy-uname ).

*--------------------------------------------------------------------
* Convert Startup TM -> FDM Application Info
*--------------------------------------------------------------------
    DATA(ls_tm_info) =
      zcl_drj_fdm_utility=>get_tm_app_info_ui5(
        iv_catalog_id      = is_tm-catalog_id
        iv_semantic_object = is_tm-object
        iv_semantic_action = is_tm-action ).

*--------------------------------------------------------------------
* TM not found in FDM
*--------------------------------------------------------------------
    IF ls_tm_info-found = abap_false.

      rs_status-status = gc_warning.

      rs_status-status_text =
        |Unable to resolve Target Mapping in FDM for dependency analysis|.

      RETURN.

    ENDIF.

**--------------------------------------------------------------------
** Only SAPUI5 supported for dependency analysis
**--------------------------------------------------------------------
*    IF ls_tm_info-application-type <>
*       /ui2/if_fdm=>gc_app_type-sapui5.
*
*      rs_status-status = gc_success.
*
*      rs_status-status_text =
*        |Dependency analysis not required for application type { ls_tm_info-application-type }|.
*
*      RETURN.
*
*    ENDIF.

*--------------------------------------------------------------------
* Read dependency information
*--------------------------------------------------------------------
    DATA(lt_dependencies) = zcl_drj_fdm_utility=>get_ui5_comp_dep_details_v2(
        iv_component = CONV /ui5/app_index_component_id( ls_tm_info-application-target-ui5-component )
        ).

*--------------------------------------------------------------------
* Check dependency authorizations
*--------------------------------------------------------------------
    DATA(ls_dep_auth) =
      check_all_ui5_depend_auth(
        it_dependency = lt_dependencies
        iv_user       = lv_user ).

*--------------------------------------------------------------------
* Dependency failure => Warning
*--------------------------------------------------------------------
    IF ls_dep_auth-success = abap_false.

      rs_status-status = gc_warning.

      rs_status-status_text =
        |Dependency authorization issue found: { ls_dep_auth-status_text }|.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Success
*--------------------------------------------------------------------
    rs_status-status = gc_success.

    rs_status-status_text =
      |All UI5 dependencies authorized for user { lv_user }|.

  ENDMETHOD.

  METHOD check_tr_app_auth.

    DATA(lv_user) = COND syuname(
                      WHEN iv_user IS NOT INITIAL
                      THEN iv_user
                      ELSE sy-uname ).

    DATA(lv_tcode) = is_tm-application-tra-code.

*--------------------------------------------------------------------
* TM contains a T-Code?
*--------------------------------------------------------------------
    IF lv_tcode IS INITIAL.
      "Assuming if Tcode is not maintained, its okay to assume authorised.
      rs_status-status = gc_success.
      rs_status-status_text = 'No transaction code found in Target Mapping'.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Check authorization S_TCODE
*--------------------------------------------------------------------
    CALL FUNCTION 'AUTHORITY_CHECK'
      EXPORTING
        user                = lv_user
        object              = 'S_TCODE'
        field1              = 'TCD'
        value1              = CONV ust12-von( lv_tcode )
      EXCEPTIONS
        user_dont_exist     = 1
        user_is_authorized  = 2
        user_not_authorized = 3
        user_is_locked      = 4
        OTHERS              = 5.

    IF sy-subrc = 2.

      rs_status-status = gc_success.

      rs_status-status_text =
        |User { lv_user } authorized for transaction { lv_tcode }|.

    ELSE.

      rs_status-status = gc_error.

      rs_status-status_text =
        |User { lv_user } NOT authorized for transaction { lv_tcode }|.

    ENDIF.

  ENDMETHOD.

  METHOD check_wda_app_auth.

    DATA(lv_user) = COND syuname(
                      WHEN iv_user IS NOT INITIAL
                      THEN iv_user
                      ELSE sy-uname ).

    DATA(lv_application) =
      is_tm-application-wda-application.

    DATA(lv_configuration) =
      is_tm-application-wda-configuration.

*--------------------------------------------------------------------
* No WDA application maintained
*--------------------------------------------------------------------
    IF lv_application IS INITIAL.

      rs_status-status = gc_success.

      rs_status-status_text =
        'No WDA application found in Target Mapping'.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Check WDA Application Authorization
*--------------------------------------------------------------------
    CALL FUNCTION 'AUTHORITY_CHECK'
      EXPORTING
        user                = lv_user
        object              = 'S_START'
        field1              = 'AUTHPGMID'
        value1              = 'R3TR'
        field2              = 'AUTHOBJTYP'
        value2              = 'WDYA'
        field3              = 'AUTHOBJNAM'
        value3              = CONV ust12-von( lv_application )
      EXCEPTIONS
        user_dont_exist     = 1
        user_is_authorized  = 2
        user_not_authorized = 3
        user_is_locked      = 4
        OTHERS              = 5.


    IF sy-subrc <> 2.

      rs_status-status = gc_error.

      rs_status-status_text =
        |User { lv_user } NOT authorized for WDA application { lv_application }|.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Configuration maintained?
*--------------------------------------------------------------------
    IF lv_configuration IS NOT INITIAL.

      CALL FUNCTION 'AUTHORITY_CHECK'
        EXPORTING
          user                = lv_user
          object              = 'S_START'
          field1              = 'AUTHPGMID'
          value1              = 'R3TR'
          field2              = 'AUTHOBJTYP'
          value2              = 'WDYC'
          field3              = 'AUTHOBJNAM'
          value3              = CONV ust12-von( lv_configuration )
        EXCEPTIONS
          user_dont_exist     = 1
          user_is_authorized  = 2
          user_not_authorized = 3
          user_is_locked      = 4
          OTHERS              = 5.

      IF sy-subrc <> 2.

        rs_status-status = gc_error.

        rs_status-status_text =
          |User { lv_user } authorized for WDA application { lv_application } but NOT authorized for configuration { lv_configuration }|.

        RETURN.

      ENDIF.

    ENDIF.

*--------------------------------------------------------------------
* Success
*--------------------------------------------------------------------
    rs_status-status = gc_success.

    IF lv_configuration IS INITIAL.

      rs_status-status_text =
        |User { lv_user } authorized for WDA application { lv_application }|.

    ELSE.

      rs_status-status_text =
        |User { lv_user } authorized for WDA application { lv_application } and configuration { lv_configuration }|.

    ENDIF.

  ENDMETHOD.

  METHOD check_multi_tms_app_auth.

    DATA(lv_user) = COND syuname(
                      WHEN iv_user IS NOT INITIAL
                      THEN iv_user
                      ELSE sy-uname ).

    DATA(lv_warning_found) = abap_false.

*--------------------------------------------------------------------
* No TMs supplied
*--------------------------------------------------------------------
    IF it_tm IS INITIAL.

      rs_status-status = gc_success.

      rs_status-status_text =
        'No Target Mappings supplied'.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Check all TMs
*--------------------------------------------------------------------
    LOOP AT it_tm ASSIGNING FIELD-SYMBOL(<ls_tm>).

      DATA(ls_tm_status) =
        check_tm_app_auth(
          is_tm   = <ls_tm>
          iv_user = lv_user ).

*--------------------------------------------------------------------
* First Error wins
*--------------------------------------------------------------------
      IF ls_tm_status-status = gc_error.

        rs_status = ls_tm_status.

        RETURN.

      ENDIF.

*--------------------------------------------------------------------
* Remember warnings
*--------------------------------------------------------------------
      IF ls_tm_status-status = gc_warning.

        lv_warning_found = abap_true.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* Final Result
*--------------------------------------------------------------------
    IF lv_warning_found = abap_true.

      rs_status-status = gc_warning.

      rs_status-status_text =
        |One or more of the { lines( it_tm ) } Target Mappings returned warnings|.

    ELSE.

      rs_status-status = gc_success.

      rs_status-status_text =
        |All { lines( it_tm ) } Target Mappings passed authorization validation|.

    ENDIF.

  ENDMETHOD.

  METHOD check_ui5_dependency_act.

    CLEAR rs_status.

    CASE is_dependency-app_type.

*--------------------------------------------------------------------
* ODATA V2
*--------------------------------------------------------------------
      WHEN 'ODATA'.

        DATA(ls_v2_act) =
          check_odata_v2_service_act(
            iv_service_name =
              CONV /iwfnd/med_mdl_srg_name(
                is_dependency-service_name )
            iv_version =
              CONV /iwfnd/med_mdl_version(
                is_dependency-service_version ) ).

*--------------------------------------------------------------------
* Follow FDM result:
* GW Active = Success
* Status text comes from SAP
*--------------------------------------------------------------------
        IF ls_v2_act-gw_active = abap_true.

          rs_status-success = abap_true.

        ELSE.

          rs_status-success = abap_false.

        ENDIF.

        rs_status-status_text =
          |ODATA { is_dependency-service_name }: { ls_v2_act-status_text }|.

*--------------------------------------------------------------------
* ODATA V4
*--------------------------------------------------------------------
      WHEN 'ODATA4'.

        DATA(ls_v4_act) =
          check_odata_v4_service_act(
            iv_group_id =
              CONV /iwfnd/v4_med_group_id(
                is_dependency-service_name ) ).

        rs_status-success =
          ls_v4_act-gw_active.

        rs_status-status_text =
          |ODATA4 { is_dependency-service_name }: { ls_v4_act-status_text }|.

*--------------------------------------------------------------------
* UI5
*--------------------------------------------------------------------
      WHEN 'UI5'.

        DATA(ls_icf_act) =
          check_icf_service_act(
            iv_url = is_dependency-url ).

        rs_status-success =
          xsdbool(
            ls_icf_act-exists = abap_true
            AND
            ls_icf_act-active = abap_true ).

        rs_status-status_text =
          |UI5 { is_dependency-service_name }: { ls_icf_act-status_text }|.

*--------------------------------------------------------------------
* Unsupported
*--------------------------------------------------------------------
      WHEN OTHERS.

        rs_status-success = abap_true.

        rs_status-status_text =
          |Unsupported dependency type { is_dependency-app_type }|.

    ENDCASE.

  ENDMETHOD.

  METHOD check_all_ui5_depend_act.

    DATA ls_dep_status TYPE ty_authorization_status.

    CLEAR rs_status.

*--------------------------------------------------------------------
* No dependencies supplied
*--------------------------------------------------------------------
    IF it_dependency IS INITIAL.

      rs_status-success = abap_true.

      rs_status-status_text =
        'No UI5 dependencies supplied'.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Check all dependencies
*--------------------------------------------------------------------
    LOOP AT it_dependency ASSIGNING FIELD-SYMBOL(<ls_dependency>).

      ls_dep_status =
        check_ui5_dependency_act(
          is_dependency = <ls_dependency> ).

*--------------------------------------------------------------------
* First failure wins
*--------------------------------------------------------------------
      IF ls_dep_status-success = abap_false.

        rs_status-success = abap_false.

        rs_status-status_text =
          |Dependency activation check failed: { ls_dep_status-status_text }|.

        RETURN.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* All dependencies passed
*--------------------------------------------------------------------
    rs_status-success = abap_true.

    rs_status-status_text =
      |All { lines( it_dependency ) } dependencies passed activation validation|.

  ENDMETHOD.

  METHOD check_sapui5_dependencies_act.

*--------------------------------------------------------------------
* Convert Startup TM -> FDM Application Info
*--------------------------------------------------------------------
    DATA(ls_tm_info) =
      zcl_drj_fdm_utility=>get_tm_app_info_ui5(
        iv_catalog_id      = is_tm-catalog_id
        iv_semantic_object = is_tm-object
        iv_semantic_action = is_tm-action ).

*--------------------------------------------------------------------
* TM not found in FDM
*--------------------------------------------------------------------
    IF ls_tm_info-found = abap_false.

      rs_status-status = gc_warning.

      rs_status-status_text =
        |Unable to resolve Target Mapping in FDM for dependency analysis|.

      RETURN.

    ENDIF.

**--------------------------------------------------------------------
** Only SAPUI5 supported for dependency analysis
**--------------------------------------------------------------------
*    IF ls_tm_info-application-type <>
*       /ui2/if_fdm=>gc_app_type-sapui5.
*
*      rs_status-status = gc_success.
*
*      rs_status-status_text =
*        |Dependency analysis not required for application type { ls_tm_info-application-type }|.
*
*      RETURN.
*
*    ENDIF.

*--------------------------------------------------------------------
* Read dependency information
*--------------------------------------------------------------------
    DATA(lt_dependencies) =
      zcl_drj_fdm_utility=>get_ui5_comp_dep_details_v2(
        iv_component = CONV /ui5/app_index_component_id( ls_tm_info-application-target-ui5-component )
       ).
*--------------------------------------------------------------------
* Check dependency authorizations
*--------------------------------------------------------------------
    DATA(ls_dep_act) =
      check_all_ui5_depend_act(
        it_dependency = lt_dependencies ).

*--------------------------------------------------------------------
* Dependency failure => Warning
*--------------------------------------------------------------------
    IF ls_dep_act-success = abap_false.

      rs_status-status = gc_warning.

      rs_status-status_text =
        |Dependency activation issue found: { ls_dep_act-status_text }|.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Success
*--------------------------------------------------------------------
  rs_status-status = gc_success.

  rs_status-status_text =
    'All UI5 dependencies are active'.

ENDMETHOD.


METHOD check_sapui5_dep_act_fast.

*--------------------------------------------------------------------
* Fast path
*
* The Startup TM already contains the resolved SAPUI5 component.
* Avoid re-resolving Catalog + Semantic Object + Action through FDM.
*--------------------------------------------------------------------
  DATA(lv_component) =
    is_tm-application-sapui5-component.

*--------------------------------------------------------------------
* Component not available
*--------------------------------------------------------------------
  IF lv_component IS INITIAL.

    rs_status-status = gc_warning.

    rs_status-status_text =
      |No SAPUI5 component maintained in Target Mapping for dependency analysis|.

    RETURN.

  ENDIF.

*--------------------------------------------------------------------
* Read dependency information directly from the TM component
*--------------------------------------------------------------------
  DATA(lt_dependencies) =
    zcl_drj_fdm_utility=>get_ui5_comp_dep_details_v2(
      iv_component =
        CONV /ui5/app_index_component_id( lv_component ) ).

*--------------------------------------------------------------------
* Check dependency activation
*--------------------------------------------------------------------
  DATA(ls_dep_act) =
    check_all_ui5_depend_act(
      it_dependency = lt_dependencies ).

*--------------------------------------------------------------------
* Dependency failure => Warning
*--------------------------------------------------------------------
  IF ls_dep_act-success = abap_false.

    rs_status-status = gc_warning.

    rs_status-status_text =
      |Dependency activation issue found: { ls_dep_act-status_text }|.

    RETURN.

  ENDIF.

*--------------------------------------------------------------------
* Success
*--------------------------------------------------------------------
  rs_status-status = gc_success.

  rs_status-status_text =
    'All UI5 dependencies are active'.

ENDMETHOD.


METHOD check_ui5_dependency_auth.

    CLEAR rs_status.

    CASE is_dependency-app_type.

*--------------------------------------------------------------------
* ODATA V2
*--------------------------------------------------------------------
      WHEN 'ODATA'.

        DATA(ls_v2_auth) =
          check_odata_v2_service_auth(
            iv_service_name =
              CONV /iwfnd/med_mdl_service_grp_id(
                is_dependency-service_name )
            iv_version =
              CONV /iwfnd/med_mdl_version(
                is_dependency-service_version )
            iv_user = iv_user ).

        rs_status-success =
          xsdbool(
            ls_v2_auth-service_found = abap_true
            AND ls_v2_auth-iwsg_auth = abap_true
            AND ls_v2_auth-iwsv_auth = abap_true ).

        rs_status-status_text =
          |ODATA { is_dependency-service_name }: { ls_v2_auth-status_text }|.

*--------------------------------------------------------------------
* ODATA V4
*--------------------------------------------------------------------
      WHEN 'ODATA4'.

        DATA(ls_v4_auth) =
          check_odata_v4_service_auth(
            iv_group_id =
              CONV /iwfnd/v4_med_group_id(
                is_dependency-service_name )
            iv_user = iv_user ).

        rs_status-success =
          xsdbool(
            ls_v4_auth-service_published = abap_true
            AND ls_v4_auth-service_auth = abap_true ).

        rs_status-status_text =
          |ODATA4 { is_dependency-service_name }: { ls_v4_auth-status_text }|.

*--------------------------------------------------------------------
* UI5
*--------------------------------------------------------------------
      WHEN 'UI5'.

        DATA(ls_icf_auth) =
          check_icf_service_auth(
            iv_url  = is_dependency-url
            iv_user = iv_user ).

        rs_status-success =
          ls_icf_auth-success.

        rs_status-status_text =
          |UI5 { is_dependency-service_name }: { ls_icf_auth-status_text }|.

*--------------------------------------------------------------------
* Unsupported
*--------------------------------------------------------------------
      WHEN OTHERS.

        rs_status-success = abap_true.

        rs_status-status_text =
          |Unsupported dependency type { is_dependency-app_type }|.

    ENDCASE.

  ENDMETHOD.

  METHOD check_all_ui5_depend_auth.

    DATA ls_dep_status TYPE ty_authorization_status.

    CLEAR rs_status.

*--------------------------------------------------------------------
* No dependencies supplied
*--------------------------------------------------------------------
    IF it_dependency IS INITIAL.

      rs_status-success = abap_true.

      rs_status-status_text =
        'No UI5 dependencies supplied'.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Check all dependencies
*--------------------------------------------------------------------
    LOOP AT it_dependency ASSIGNING FIELD-SYMBOL(<ls_dependency>).

      ls_dep_status =
        check_ui5_dependency_auth(
          is_dependency = <ls_dependency>
          iv_user       = iv_user ).

*--------------------------------------------------------------------
* First failure wins
*--------------------------------------------------------------------
      IF ls_dep_status-success = abap_false.

        rs_status-success = abap_false.

        rs_status-status_text =
          |Dependency check failed: { ls_dep_status-status_text }|.

        RETURN.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* All dependencies passed
*--------------------------------------------------------------------
    rs_status-success = abap_true.

    rs_status-status_text =
      |All { lines( it_dependency ) } dependencies passed authorization validation|.

  ENDMETHOD.

  METHOD check_all_wda_depend_act.

    rs_status-status = gc_success.

*--------------------------------------------------------------------
* No dependencies
*--------------------------------------------------------------------
    IF it_services IS INITIAL.

      rs_status-status_text =
        'No WDA dependencies found'.

      RETURN.

    ENDIF.

*--------------------------------------------------------------------
* Check every dependency
*--------------------------------------------------------------------
    LOOP AT it_services ASSIGNING FIELD-SYMBOL(<ls_service>).

      DATA(lv_url) =
        <ls_service>-service_obj->get_url( ).

      IF lv_url IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_icf_status) =
        check_icf_service_act(
          iv_url = lv_url ).

      IF ls_icf_status-active <> abap_true.

        rs_status-status = gc_error.

        rs_status-status_text =
          |Inactive WDA dependency found: { lv_url }|.

        RETURN.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* Success
*--------------------------------------------------------------------
    rs_status-status = gc_success.

    rs_status-status_text =
      |All { lines( it_services ) } WDA dependencies are active|.

  ENDMETHOD.


  METHOD check_ui5_dep_act_detail.

    CLEAR rs_result.

*--------------------------------------------------------------------
* Fill dependency identity
*--------------------------------------------------------------------
    rs_result-dependency_type =
      is_dependency-app_type.

    rs_result-service_name =
      is_dependency-service_name.

    rs_result-service_version =
      is_dependency-service_version.

    rs_result-url =
      is_dependency-url.

*--------------------------------------------------------------------
* Supported dependency types
*--------------------------------------------------------------------
    CASE is_dependency-app_type.

      WHEN 'ODATA'
        OR 'ODATA4'
        OR 'UI5'.

        DATA(ls_status) =
          check_ui5_dependency_act(
            is_dependency = is_dependency ).

        rs_result-success =
          ls_status-success.

        rs_result-status =
          COND #(
            WHEN ls_status-success = abap_true
            THEN gc_success
            ELSE gc_warning ).

        rs_result-status_text =
          ls_status-status_text.

*--------------------------------------------------------------------
* Unsupported dependency types
* Important:
* Existing private method keeps unsupported as success.
* For this analyzer, unsupported should be visible as warning.
*--------------------------------------------------------------------
      WHEN OTHERS.

        rs_result-success =
          abap_false.

        rs_result-status =
          gc_warning.

        rs_result-status_text =
          |Unsupported dependency type { is_dependency-app_type }|.

    ENDCASE.

  ENDMETHOD.


  METHOD get_ui5_dep_act_details.

    DATA lt_tm TYPE zcl_drj_flp_start_up_utility=>tty_tm.

    DATA lv_can_sort_compress TYPE abap_bool.

    DATA lv_effective_catalog_id TYPE /ui2/page_id.

    CLEAR:
      rt_result,
      lv_can_sort_compress.

*--------------------------------------------------------------------
* Mandatory input protection
*--------------------------------------------------------------------
    IF iv_semantic_object IS INITIAL
       OR iv_semantic_action IS INITIAL.
      RETURN.
    ENDIF.

    lv_effective_catalog_id =
      CONV /ui2/page_id( iv_catalog_id ).

*--------------------------------------------------------------------
* Validate configured catalog against this system
*
* If it does not exist locally, treat it like no catalog was supplied
* and use the existing user/SO/action fallback.
*--------------------------------------------------------------------
    IF lv_effective_catalog_id IS NOT INITIAL
       AND zcl_drj_flp_start_up_utility=>catalog_exists(
             iv_catalog_id = lv_effective_catalog_id ) = abap_false.

      CLEAR lv_effective_catalog_id.

    ENDIF.

*--------------------------------------------------------------------
* Valid local catalog supplied and TM exists in that catalog
*
* Important:
* This is a catalog-filtered subset.
* Do NOT call SORT_AND_COMPRESS_TMS for this result.
*--------------------------------------------------------------------
    IF lv_effective_catalog_id IS NOT INITIAL.

      lt_tm =
        zcl_drj_flp_start_up_utility=>get_all_tms_for_cat_so_sa(
          iv_catalog_id = lv_effective_catalog_id
          iv_object     = CONV /ui2/semantic_object( iv_semantic_object )
          iv_action     = CONV /ui2/semantic_action( iv_semantic_action ) ).

      lv_can_sort_compress =
        abap_false.

*--------------------------------------------------------------------
* No catalog supplied
*--------------------------------------------------------------------
    ELSE.

*------------------------------------------------------------------
* First try user's assigned startup TMs.
* Do NOT sort/compress this user-specific subset.
*------------------------------------------------------------------
      IF iv_user IS NOT INITIAL.

        lt_tm =
          zcl_drj_flp_start_up_utility=>user_assigned_tms_for_so_sa(
            iv_user   = iv_user
            iv_object = CONV /ui2/semantic_object( iv_semantic_object )
            iv_action = CONV /ui2/semantic_action( iv_semantic_action ) ).

        lv_can_sort_compress =
          abap_false.

      ENDIF.

*------------------------------------------------------------------
* Fallback to full SO/SA universe.
* This is the only safe place to sort/compress.
*------------------------------------------------------------------
      IF lt_tm IS INITIAL.

        lt_tm =
          zcl_drj_flp_start_up_utility=>lookup_all_tms(
            iv_object = CONV /ui2/semantic_object( iv_semantic_object )
            iv_action = CONV /ui2/semantic_action( iv_semantic_action ) ).

        lv_can_sort_compress =
          abap_true.

      ENDIF.

    ENDIF.

*--------------------------------------------------------------------
* No TMs found
*--------------------------------------------------------------------
    IF lt_tm IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Minimize only if full SO/SA universe was used
*--------------------------------------------------------------------
    IF lv_can_sort_compress = abap_true.

      lt_tm =
        zcl_drj_flp_start_up_utility=>sort_and_compress_tms(
          it_tm = lt_tm ).

    ENDIF.

*--------------------------------------------------------------------
* Build one output row per UI5 dependency
*--------------------------------------------------------------------
    DATA lv_sequence TYPE i.

    LOOP AT lt_tm ASSIGNING FIELD-SYMBOL(<ls_tm>).

*--------------------------------------------------------------------
* Dependency analysis only makes sense for SAPUI5 target mappings
*--------------------------------------------------------------------
      IF <ls_tm>-application_type <> 'SAPUI5'.
        CONTINUE.
      ENDIF.

*--------------------------------------------------------------------
* Convert Startup TM -> FDM Application Info
*--------------------------------------------------------------------
      DATA(ls_tm_info) =
        zcl_drj_fdm_utility=>get_tm_app_info_ui5(
          iv_catalog_id      = <ls_tm>-catalog_id
          iv_semantic_object = <ls_tm>-object
          iv_semantic_action = <ls_tm>-action ).

*--------------------------------------------------------------------
* If FDM could not resolve it, skip dependency rows.
* This method returns one row per dependency only.
*--------------------------------------------------------------------
      IF ls_tm_info-found = abap_false.
        CONTINUE.
      ENDIF.

*--------------------------------------------------------------------
* Component is required for dependency lookup
*--------------------------------------------------------------------
      DATA(lv_component) =
        CONV /ui5/app_index_component_id(
          ls_tm_info-application-target-ui5-component ).

      IF lv_component IS INITIAL.
        CONTINUE.
      ENDIF.

*--------------------------------------------------------------------
* Read dependency information
*--------------------------------------------------------------------
      DATA(lt_dependencies) =
        zcl_drj_fdm_utility=>get_ui5_comp_dep_details_v2(
          iv_component = lv_component ).

*--------------------------------------------------------------------
* One row per dependency
*--------------------------------------------------------------------
      LOOP AT lt_dependencies ASSIGNING FIELD-SYMBOL(<ls_dependency>).

        lv_sequence += 1.

        DATA(ls_detail) =
          check_ui5_dep_act_detail(
            is_dependency = <ls_dependency> ).

        ls_detail-sequence =
          lv_sequence.

        ls_detail-semantic_object =
          iv_semantic_object.

        ls_detail-semantic_action =
          iv_semantic_action.

        ls_detail-catalog_id =
          <ls_tm>-catalog_id.

        ls_detail-component_id =
          ls_tm_info-application-target-ui5-component.

        APPEND ls_detail TO rt_result.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
