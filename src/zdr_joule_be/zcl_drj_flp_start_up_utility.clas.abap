CLASS zcl_drj_flp_start_up_utility DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
  "====================================================================
  " FLP Start-Up Utility
  "
  " Central utility layer for FLP Target Mapping lookup, catalog
  " resolution, user start-up content and role/catalog relationships.
  "
  " TARGET MAPPING LOOKUP
  "
  " ├─ lookup_all_tms
  " │   ├─ /ui2/cl_tm_pb_access->get_target_mappings
  " │   ├─ build universal TM cache once per ABAP session
  " │   │   └─ mt_lookup_all_tms
  " │   ├─ resolve optional catalog filter
  " │   │   └─ resolve_tm_catalog_ids
  " │   └─ filter cached TMs by
  " │       ├─ Catalog + Semantic Object + Action
  " │       ├─ Catalog + Semantic Object
  " │       ├─ Catalog + Action
  " │       ├─ Catalog only
  " │       ├─ Semantic Object + Action
  " │       ├─ Semantic Object only
  " │       └─ Semantic Action only
  " │
  " ├─ lookup_all_tms_no_buffer
  " │   └─ /ui2/cl_tm_pb_access->get_target_mappings
  " │       └─ fresh read with filters pushed to SAP API
  " │
  " ├─ get_all_tms_for_cat_so_sa
  " │   └─ lookup_all_tms
  " │       └─ Catalog + Semantic Object + Action
  " │
  " └─ sort_and_compress_tms
  "     ├─ follow REF_CATALOG_ID hierarchy to root TM
  "     └─ deduplicate by UIAD_ID / MAPPING_ID
  "
  " CATALOG RESOLUTION
  "
  " ├─ resolve_catalog_id
  " │   ├─ cache /ui2/cl_fdm_catalog_api catalog keys
  " │   ├─ remove FLP catalog prefixes
  " │   │   ├─ X-SAP-UI2-CATALOGPAGE
  " │   │   └─ X-SAP-UI2-ADCAT
  " │   ├─ exact logical catalog lookup
  " │   └─ fallback *_APPS → *_BE_APPS when present
  " │
  " ├─ resolve_tm_catalog_ids
  " │   ├─ resolve_catalog_id
  " │   ├─ map logical catalog to actual TM-index representation
  " │   │   ├─ X-SAP-UI2-CATALOGPAGE:<catalog>
  " │   │   └─ X-SAP-UI2-ADCAT:<catalog>:<system alias>
  " │   └─ return actual IDs found in universal TM cache
  " │
  " └─ catalog_exists
  "     └─ resolve_catalog_id
  "
  " INTENT → CATALOG / ROLE RESOLUTION
  "
  " ├─ get_all_cat_ref_for_so_sa
  " │   ├─ lookup_all_tms_no_buffer
  " │   └─ return detailed current TM/catalog/reference information
  " │
  " ├─ get_all_cat_for_so_sa
  " │   └─ get_all_cat_ref_for_so_sa
  " │       └─ unique catalog IDs for Semantic Object + Action
  " │
  " ├─ get_roles_for_catalogs
  " │   └─ /ui2/cl_pfcg_utils=>get_roles_for_catalogs
  " │
  " ├─ get_roles_for_so_sa
  " │   ├─ get_all_cat_ref_for_so_sa
  " │   └─ get_roles_for_catalogs
  " │
  " └─ get_composite_roles_for_roles
  "     └─ /ui2/cl_pfcg_utils=>get_composite_roles_of_roles
  "
  " USER ROLE / FIORI CONTENT
  "
  " ├─ get_roles_of_user
  " │   └─ /ui2/cl_pfcg_utils=>get_roles_of_user
  " │
  " └─ get_fiori_roles_of_user
  "     ├─ get_roles_of_user
  "     ├─ get_catalogs_groups_for_roles
  "     ├─ get_space_for_roles
  "     └─ return only roles containing Fiori content
  "
  " USER START-UP TARGET MAPPINGS
  "
  " ├─ lookup_user_start_up_tms
  " │   ├─ resolve effective user
  " │   ├─ /ui2/cl_pfcg_utils=>get_catalogs_by_user
  " │   ├─ /ui2/cl_tm_pb_access->get_target_mappings
  " │   ├─ cache startup TMs per user
  " │   │   └─ mt_lookup_user_startup_tms
  " │   └─ optional filtering by Catalog / SO / Action
  " │
  " ├─ get_user_start_up_tms
  " │   └─ lookup_user_start_up_tms
  " │
  " ├─ user_assigned_tms_for_so_sa
  " │   └─ lookup_user_start_up_tms
  " │       └─ User + Semantic Object + Action
  " │
  " └─ has_start_up_tm
  "     └─ lookup_user_start_up_tms
  "         └─ existence check for User + Semantic Object + Action
  "
  " CATALOG-AWARE USER TM CHECKS
  "
  " ├─ has_tm_direct_catalog
  " │   └─ lookup_user_start_up_tms
  " │       └─ direct User + Catalog + SO + Action match
  " │
  " └─ has_tm_indirect_catalog
  "     ├─ resolve_tm_catalog_ids
  "     ├─ check direct catalog match
  "     └─ search_catalog_recursive
  "         └─ traverse REF_CATALOG_ID hierarchy for SO + Action
  "====================================================================
  PUBLIC SECTION.
    TYPES:
      ty_tm  TYPE /ui2/if_tm_index_access=>tp_s_tm_int,
      tty_tm TYPE /ui2/if_tm_index_access=>tp_t_tm_int.

    TYPES tt_role_name TYPE /ui2/cl_pfcg_utils=>tt_role_name.

    TYPES:
      BEGIN OF ty_intent_cat,
        catalog_id TYPE string,
      END OF ty_intent_cat,
      tty_intent_cat TYPE SORTED TABLE OF ty_intent_cat
        WITH UNIQUE KEY catalog_id .

    TYPES:
      BEGIN OF ty_intent_cat_and_ref,
        catalog_id     TYPE string,
        ref_catalog_id TYPE string,
      END OF ty_intent_cat_and_ref,

      tty_intent_cat_and_ref TYPE SORTED TABLE OF ty_intent_cat_and_ref
        WITH UNIQUE KEY catalog_id ref_catalog_id.

    TYPES tty_role_catalogs TYPE STANDARD TABLE OF /ui2/cl_pfcg_utils=>ts_catalog
      WITH EMPTY KEY.

    TYPES:
      tp_s_application TYPE /ui2/if_tm_index_access=>tp_s_application,
      tp_t_property    TYPE /ui2/if_tm_index_access=>tp_t_property.

    TYPES tty_tm_catalog_ids TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    TYPES:
      BEGIN OF tp_s_tm_detailed_info,
        object           TYPE string,
        action           TYPE string,
        text             TYPE string,
        application_type TYPE string,
        target_id        TYPE string,
        mapping_id       TYPE string,
        application      TYPE tp_s_application,
        system_alias     TYPE string,
        short_guid       TYPE string,
        chip_id          TYPE string,
        catalog_id       TYPE string,
        scope            TYPE wdr_pers_scope,
        ref_chip_id      TYPE string,
        ref_catalog_id   TYPE string,
        ref_scope        TYPE wdr_pers_scope,
        properties       TYPE tp_t_property,
        uiad_id          TYPE /ui2/ad_mm_app_id,
      END OF tp_s_tm_detailed_info.

    TYPES tp_t_tm_detailed_info TYPE STANDARD TABLE OF tp_s_tm_detailed_info
      WITH EMPTY KEY.


    CLASS-METHODS lookup_all_tms
      IMPORTING
        iv_catalog_id TYPE /ui2/page_id OPTIONAL
        iv_object     TYPE /ui2/semantic_object OPTIONAL
        iv_action     TYPE /ui2/semantic_action OPTIONAL
      RETURNING
        VALUE(rt_tm)  TYPE tty_tm.


    CLASS-METHODS lookup_all_tms_no_buffer
      IMPORTING
        iv_catalog_id TYPE /ui2/page_id OPTIONAL
        iv_object     TYPE /ui2/semantic_object OPTIONAL
        iv_action     TYPE /ui2/semantic_action OPTIONAL
      RETURNING
        VALUE(rt_tm)  TYPE tty_tm.

    CLASS-METHODS sort_and_compress_tms
      IMPORTING
        it_tm        TYPE tty_tm
      RETURNING
        VALUE(rt_tm) TYPE tty_tm.

    CLASS-METHODS lookup_user_start_up_tms
      IMPORTING
        iv_user       TYPE syuname OPTIONAL
        iv_catalog_id TYPE /ui2/page_id OPTIONAL
        iv_object     TYPE /ui2/semantic_object OPTIONAL
        iv_action     TYPE /ui2/semantic_action OPTIONAL
      RETURNING
        VALUE(rt_tm)  TYPE tty_tm.

    CLASS-METHODS get_all_tms_for_cat_so_sa
      IMPORTING
        iv_catalog_id TYPE /ui2/page_id
        iv_object     TYPE /ui2/semantic_object
        iv_action     TYPE /ui2/semantic_action
      RETURNING
        VALUE(rt_tm)  TYPE tty_tm.

    CLASS-METHODS resolve_catalog_id
      IMPORTING
        iv_catalog_id        TYPE /ui2/page_id
      RETURNING
        VALUE(rv_catalog_id) TYPE /ui2/page_id.

    CLASS-METHODS resolve_tm_catalog_ids
      IMPORTING
        iv_catalog_id            TYPE /ui2/page_id
      RETURNING
        VALUE(rt_tm_catalog_ids) TYPE tty_tm_catalog_ids.

    CLASS-METHODS catalog_exists
      IMPORTING
        iv_catalog_id    TYPE /ui2/page_id
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    CLASS-METHODS tm_exists_in_catalog
      IMPORTING
        iv_catalog_id      TYPE /ui2/page_id
        iv_semantic_object TYPE /ui2/semantic_object
        iv_semantic_action TYPE /ui2/semantic_action
      RETURNING
        VALUE(rv_exists)   TYPE abap_bool.

    CLASS-METHODS get_all_cat_for_so_sa
      IMPORTING
        iv_object          TYPE /ui2/semantic_object
        iv_action          TYPE /ui2/semantic_action
      RETURNING
        VALUE(rt_catalogs) TYPE tty_intent_cat.

    CLASS-METHODS get_all_cat_ref_for_so_sa
      IMPORTING
        iv_object         TYPE /ui2/semantic_object
        iv_action         TYPE /ui2/semantic_action
      RETURNING
        VALUE(rt_tm_info) TYPE tp_t_tm_detailed_info.

    CLASS-METHODS get_roles_for_catalogs
      IMPORTING
        it_catalogs        TYPE /ui2/cl_pfcg_utils=>tt_catalog_ids
      RETURNING
        VALUE(rt_role_ids) TYPE /ui2/if_nwbc_runtime=>t_role_ids.

    CLASS-METHODS get_catalogs_for_roles
      IMPORTING
        it_role_ids        TYPE /ui2/if_nwbc_runtime=>t_role_ids
      RETURNING
        VALUE(rt_catalogs) TYPE tty_role_catalogs.

    CLASS-METHODS get_composite_roles_for_roles
      IMPORTING
        it_role_ids                  TYPE /ui2/if_nwbc_runtime=>t_role_ids
        iv_exclude_roles_w_own_menu  TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_composite_role_ids) TYPE /ui2/if_nwbc_runtime=>t_role_ids.

    CLASS-METHODS get_roles_for_so_sa
      IMPORTING
        iv_object          TYPE /ui2/semantic_object
        iv_action          TYPE /ui2/semantic_action
      RETURNING
        VALUE(rt_role_ids) TYPE /ui2/if_nwbc_runtime=>t_role_ids.

    CLASS-METHODS get_roles_of_user
      IMPORTING
        iv_user             TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rt_role_name) TYPE tt_role_name.

    CLASS-METHODS get_fiori_roles_of_user
      IMPORTING
        iv_user             TYPE syuname DEFAULT sy-uname
      RETURNING
        VALUE(rt_role_name) TYPE tt_role_name.

    CLASS-METHODS get_user_start_up_tms
      IMPORTING
        iv_user      TYPE syuname OPTIONAL
      RETURNING
        VALUE(rt_tm) TYPE tty_tm.

    CLASS-METHODS user_assigned_tms_for_so_sa
      IMPORTING
        iv_user      TYPE syuname OPTIONAL
        iv_object    TYPE /ui2/semantic_object OPTIONAL
        iv_action    TYPE /ui2/semantic_action OPTIONAL
      RETURNING
        VALUE(rt_tm) TYPE tty_tm.


    CLASS-METHODS has_start_up_tm
      IMPORTING
        iv_user            TYPE syuname OPTIONAL
        iv_semantic_object TYPE /ui2/semantic_object
        iv_semantic_action TYPE /ui2/semantic_action
      RETURNING
        VALUE(rv_found)    TYPE abap_bool.

    CLASS-METHODS has_tm_direct_catalog
      IMPORTING
        iv_user            TYPE syuname OPTIONAL
        iv_catalog_id      TYPE /ui2/page_id
        iv_semantic_object TYPE /ui2/semantic_object
        iv_semantic_action TYPE /ui2/semantic_action
      RETURNING
        VALUE(rv_found)    TYPE abap_bool.

    CLASS-METHODS has_tm_indirect_catalog
      IMPORTING
        iv_user            TYPE syuname OPTIONAL
        iv_catalog_id      TYPE /ui2/page_id
        iv_semantic_object TYPE /ui2/semantic_object
        iv_semantic_action TYPE /ui2/semantic_action
      RETURNING
        VALUE(rv_found)    TYPE abap_bool.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES tty_tm_lookup_cache TYPE STANDARD TABLE OF ty_tm
      WITH EMPTY KEY
      WITH NON-UNIQUE SORTED KEY k_cat_obj_act COMPONENTS catalog_id object action
      WITH NON-UNIQUE SORTED KEY k_cat_act     COMPONENTS catalog_id action
      WITH NON-UNIQUE SORTED KEY k_obj_act     COMPONENTS object action
      WITH NON-UNIQUE SORTED KEY k_action      COMPONENTS action.

    CLASS-DATA mt_lookup_user_startup_tms TYPE tty_tm.
    CLASS-DATA mv_startup_user   TYPE syuname.
    CLASS-DATA mv_startup_loaded TYPE abap_bool.

    CLASS-DATA mt_lookup_all_tms TYPE tty_tm_lookup_cache.
    CLASS-DATA mv_lookup_all_tms_loaded TYPE abap_bool.

    CLASS-DATA mt_catalog_keys TYPE /ui2/if_fdm=>tt_catalog_key.
    CLASS-DATA mv_catalog_keys_loaded TYPE abap_bool.

    CLASS-METHODS search_catalog_recursive
      IMPORTING
        iv_catalog_id      TYPE string
        iv_target_catalog  TYPE string
        iv_semantic_object TYPE /ui2/semantic_object
        iv_semantic_action TYPE /ui2/semantic_action
      RETURNING
        VALUE(rv_found)    TYPE abap_bool.

ENDCLASS.



CLASS zcl_drj_flp_start_up_utility IMPLEMENTATION.

  METHOD lookup_all_tms.

    DATA lv_object TYPE /ui2/semantic_object.
    DATA lv_action TYPE /ui2/semantic_action.

    FIELD-SYMBOLS <ls_tm> TYPE ty_tm.


*--------------------------------------------------------------------
* Build universal cache once per ABAP session
*--------------------------------------------------------------------
    IF mv_lookup_all_tms_loaded IS INITIAL.

      DATA(lo_tm_pb_access) =
        NEW /ui2/cl_tm_pb_access( ).

      DATA(lt_all_tms) =
        lo_tm_pb_access->get_target_mappings(
          ir_catalogs = VALUE #( )
          ir_object   = VALUE #( )
          ir_action   = VALUE #( )
          ir_tm_id    = VALUE #( )
          ir_chip_id  = VALUE #( ) ).

      CLEAR mt_lookup_all_tms.

      INSERT LINES OF lt_all_tms
        INTO TABLE mt_lookup_all_tms.

      mv_lookup_all_tms_loaded = abap_true.

    ENDIF.


*--------------------------------------------------------------------
* Prepare filters
*--------------------------------------------------------------------
    CLEAR rt_tm.

    lv_object = iv_object.
    lv_action = iv_action.


*--------------------------------------------------------------------
* Resolve supplied catalog to the actual TM-index catalog ID(s)
*
* Examples:
*
* SAP_A4C_BC_DEV
*   -> X-SAP-UI2-CATALOGPAGE:SAP_A4C_BC_DEV
*
* SAP_TC_CA_BP_APPS
*   -> X-SAP-UI2-ADCAT:SAP_TC_CA_BP_BE_APPS:S4CMD
*--------------------------------------------------------------------
    DATA lt_tm_catalog_ids TYPE tty_tm_catalog_ids.

    IF iv_catalog_id IS NOT INITIAL.

      lt_tm_catalog_ids =
        resolve_tm_catalog_ids(
          iv_catalog_id = iv_catalog_id ).

*------------------------------------------------------------------
* Catalog was supplied but cannot be resolved in this system.
*
* Important:
* Do NOT fall through to an unrestricted SO/SA lookup.
*------------------------------------------------------------------
      IF lt_tm_catalog_ids IS INITIAL.
        RETURN.
      ENDIF.

    ENDIF.


*--------------------------------------------------------------------
* No filter: return complete universal cache
*--------------------------------------------------------------------
    IF iv_catalog_id IS INITIAL
       AND lv_object IS INITIAL
       AND lv_action IS INITIAL.

      INSERT LINES OF mt_lookup_all_tms
        INTO TABLE rt_tm.

      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Catalog + Semantic Object + Semantic Action
*--------------------------------------------------------------------
    IF iv_catalog_id IS NOT INITIAL
       AND lv_object IS NOT INITIAL
       AND lv_action IS NOT INITIAL.

      LOOP AT lt_tm_catalog_ids
        INTO DATA(lv_tm_catalog_id).

        LOOP AT mt_lookup_all_tms
          ASSIGNING <ls_tm>
          USING KEY k_cat_obj_act
          WHERE catalog_id = lv_tm_catalog_id
            AND object     = lv_object
            AND action     = lv_action.

          INSERT <ls_tm> INTO TABLE rt_tm.

        ENDLOOP.

      ENDLOOP.

      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Catalog + Semantic Object
*--------------------------------------------------------------------
    IF iv_catalog_id IS NOT INITIAL
       AND lv_object IS NOT INITIAL.

      LOOP AT lt_tm_catalog_ids
        INTO lv_tm_catalog_id.

        LOOP AT mt_lookup_all_tms
          ASSIGNING <ls_tm>
          USING KEY k_cat_obj_act
          WHERE catalog_id = lv_tm_catalog_id
            AND object     = lv_object.

          INSERT <ls_tm> INTO TABLE rt_tm.

        ENDLOOP.

      ENDLOOP.

      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Catalog + Semantic Action
*--------------------------------------------------------------------
    IF iv_catalog_id IS NOT INITIAL
       AND lv_action IS NOT INITIAL.

      LOOP AT lt_tm_catalog_ids
        INTO lv_tm_catalog_id.

        LOOP AT mt_lookup_all_tms
          ASSIGNING <ls_tm>
          USING KEY k_cat_act
          WHERE catalog_id = lv_tm_catalog_id
            AND action     = lv_action.

          INSERT <ls_tm> INTO TABLE rt_tm.

        ENDLOOP.

      ENDLOOP.

      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Catalog only
*--------------------------------------------------------------------
    IF iv_catalog_id IS NOT INITIAL.

      LOOP AT lt_tm_catalog_ids
        INTO lv_tm_catalog_id.

        LOOP AT mt_lookup_all_tms
          ASSIGNING <ls_tm>
          USING KEY k_cat_obj_act
          WHERE catalog_id = lv_tm_catalog_id.

          INSERT <ls_tm> INTO TABLE rt_tm.

        ENDLOOP.

      ENDLOOP.

      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Semantic Object + Semantic Action
*--------------------------------------------------------------------
    IF lv_object IS NOT INITIAL
       AND lv_action IS NOT INITIAL.

      LOOP AT mt_lookup_all_tms
        ASSIGNING <ls_tm>
        USING KEY k_obj_act
        WHERE object = lv_object
          AND action = lv_action.

        INSERT <ls_tm> INTO TABLE rt_tm.

      ENDLOOP.

      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Semantic Object only
*--------------------------------------------------------------------
    IF lv_object IS NOT INITIAL.

      LOOP AT mt_lookup_all_tms
        ASSIGNING <ls_tm>
        USING KEY k_obj_act
        WHERE object = lv_object.

        INSERT <ls_tm> INTO TABLE rt_tm.

      ENDLOOP.

      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Semantic Action only
*--------------------------------------------------------------------
    IF lv_action IS NOT INITIAL.

      LOOP AT mt_lookup_all_tms
        ASSIGNING <ls_tm>
        USING KEY k_action
        WHERE action = lv_action.

        INSERT <ls_tm> INTO TABLE rt_tm.

      ENDLOOP.

      RETURN.

    ENDIF.

  ENDMETHOD.

  METHOD lookup_all_tms_no_buffer.

    CONSTANTS lc_catalog_prefix TYPE string
      VALUE 'X-SAP-UI2-CATALOGPAGE:'. ""TODO REMOVE THIS

*--------------------------------------------------------------------
* Local range variables
*--------------------------------------------------------------------
    DATA lr_catalogs TYPE /ui2/cl_tm_pb_access=>ttr_catalogs.
    DATA lr_object   TYPE /ui2/cl_tm_pb_access=>ttr_object.
    DATA lr_action   TYPE /ui2/cl_tm_pb_access=>ttr_action.

*--------------------------------------------------------------------
* Catalog range
*
* Important:
* /UI2/CL_TM_PB_ACCESS expects catalog IDs in FLP-internal format,
* for example:
*   X-SAP-UI2-CATALOGPAGE:SAP_TC_...
*--------------------------------------------------------------------
    IF iv_catalog_id IS NOT INITIAL.

      DATA(lv_catalog_id) = CONV /ui2/page_id( iv_catalog_id ).

      IF CONV string( lv_catalog_id ) NP 'X-SAP-UI2-CATALOGPAGE:*'.

        lv_catalog_id =
          CONV /ui2/page_id(
            lc_catalog_prefix &&
            CONV string( lv_catalog_id ) ).

      ENDIF.

      lr_catalogs =
        VALUE /ui2/cl_tm_pb_access=>ttr_catalogs(
          (
            sign   = 'I'
            option = 'EQ'
            low    = lv_catalog_id
          )
        ).

    ENDIF.

*--------------------------------------------------------------------
* Semantic Object range
*--------------------------------------------------------------------
    IF iv_object IS NOT INITIAL.

      lr_object =
        VALUE /ui2/cl_tm_pb_access=>ttr_object(
          (
            sign   = 'I'
            option = 'EQ'
            low    = iv_object
          )
        ).

    ENDIF.

*--------------------------------------------------------------------
* Semantic Action range
*--------------------------------------------------------------------
    IF iv_action IS NOT INITIAL.

      lr_action =
        VALUE /ui2/cl_tm_pb_access=>ttr_action(
          (
            sign   = 'I'
            option = 'EQ'
            low    = iv_action
          )
        ).

    ENDIF.

*--------------------------------------------------------------------
* Read fresh TM data without using our class buffer.
*
* The filters are pushed down into /UI2/CL_TM_PB_ACCESS.
* Do not read universal TM data and delete/filter afterwards here.
*--------------------------------------------------------------------
    DATA(lo_tm_pb_access) =
      NEW /ui2/cl_tm_pb_access( ).

    rt_tm =
      lo_tm_pb_access->get_target_mappings(
        ir_catalogs = lr_catalogs
        ir_object   = lr_object
        ir_action   = lr_action
        ir_tm_id    = VALUE #( )
        ir_chip_id  = VALUE #( ) ).

  ENDMETHOD.


  METHOD sort_and_compress_tms.

*--------------------------------------------------------------------
* Helper types
*--------------------------------------------------------------------
    TYPES:
      BEGIN OF ty_catalog,
        catalog_id     TYPE string,
        ref_catalog_id TYPE string,
      END OF ty_catalog.

    TYPES:
      BEGIN OF ty_seen,
        dedupe_key TYPE string,
      END OF ty_seen.

*--------------------------------------------------------------------
* Local data
*--------------------------------------------------------------------
    DATA lt_catalogs TYPE HASHED TABLE OF ty_catalog
      WITH UNIQUE KEY catalog_id.

    DATA lt_seen TYPE HASHED TABLE OF ty_seen
      WITH UNIQUE KEY dedupe_key.

*--------------------------------------------------------------------
* Build catalog lookup
*--------------------------------------------------------------------
    LOOP AT it_tm ASSIGNING FIELD-SYMBOL(<ls_tm>).

      INSERT VALUE ty_catalog(
        catalog_id     = <ls_tm>-catalog_id
        ref_catalog_id = <ls_tm>-ref_catalog_id )
        INTO TABLE lt_catalogs.

    ENDLOOP.

*--------------------------------------------------------------------
* Build result
*--------------------------------------------------------------------
    CLEAR rt_tm.

    LOOP AT it_tm ASSIGNING FIELD-SYMBOL(<ls_source>).

      DATA(lv_catalog) = <ls_source>-catalog_id.

*------------------------------------------------------------------
* Walk up hierarchy until root reached
*------------------------------------------------------------------
      WHILE lv_catalog IS NOT INITIAL.

        READ TABLE lt_catalogs
          ASSIGNING FIELD-SYMBOL(<ls_cat>)
          WITH TABLE KEY catalog_id = lv_catalog.

        IF sy-subrc <> 0.
          EXIT.
        ENDIF.

*------------------------------------------------------------------
* Broken self-reference protection
*------------------------------------------------------------------
        IF <ls_cat>-catalog_id = <ls_cat>-ref_catalog_id.
          EXIT.
        ENDIF.

*------------------------------------------------------------------
* Root reached
*------------------------------------------------------------------
        IF <ls_cat>-ref_catalog_id IS INITIAL.

*----------------------------------------------------------------
* Find the root TM row
*----------------------------------------------------------------
          READ TABLE it_tm
            ASSIGNING FIELD-SYMBOL(<ls_root_tm>)
            WITH KEY catalog_id     = <ls_cat>-catalog_id
                     ref_catalog_id = ''.

          IF sy-subrc <> 0.
            EXIT.
          ENDIF.

*----------------------------------------------------------------
* Build dedupe key
*----------------------------------------------------------------
          DATA lv_key TYPE string.

          IF <ls_root_tm>-uiad_id IS NOT INITIAL.

            lv_key =
              |UIAD:{ CONV string( <ls_root_tm>-uiad_id ) }|.

          ELSE.

            lv_key =
              |MAP:{ CONV string( <ls_root_tm>-mapping_id ) }|.

          ENDIF.

*----------------------------------------------------------------
* Already added?
*----------------------------------------------------------------
          READ TABLE lt_seen
            WITH TABLE KEY dedupe_key = lv_key
            TRANSPORTING NO FIELDS.

          IF sy-subrc = 0.
            EXIT.
          ENDIF.

          INSERT VALUE ty_seen(
            dedupe_key = lv_key )
            INTO TABLE lt_seen.

*----------------------------------------------------------------
* Keep root TM
*
* IMPORTANT:
* rt_tm is a sorted table, so do NOT use APPEND here.
*----------------------------------------------------------------
          INSERT <ls_root_tm> INTO TABLE rt_tm.

          EXIT.

        ENDIF.

*------------------------------------------------------------------
* Continue climbing
*------------------------------------------------------------------
        lv_catalog = <ls_cat>-ref_catalog_id.

      ENDWHILE.

    ENDLOOP.

  ENDMETHOD.

  METHOD lookup_user_start_up_tms.

*--------------------------------------------------------------------
* Resolve user
*--------------------------------------------------------------------
    DATA(lv_user) =
      COND syuname(
        WHEN iv_user IS NOT INITIAL
        THEN iv_user
        ELSE sy-uname ).

*--------------------------------------------------------------------
* Build user-specific cache once per ABAP session + user
*
* Important:
* mt_lookup_user_startup_tms is not universal.
* It depends on the supplied/current user.
*--------------------------------------------------------------------
    IF mv_startup_loaded IS INITIAL
       OR mv_startup_user <> lv_user.

      CLEAR mt_lookup_user_startup_tms.

*------------------------------------------------------------------
* Read assigned catalogs
*------------------------------------------------------------------
      DATA lt_catalogs TYPE /ui2/if_tm_index_access=>tp_t_catalog_id.

      /ui2/cl_pfcg_utils=>get_catalogs_by_user(
        EXPORTING
          iv_user     = lv_user
        IMPORTING
          et_catalogs = lt_catalogs ).

      mv_startup_user   = lv_user.
      mv_startup_loaded = abap_true.

      IF lt_catalogs IS INITIAL.
        RETURN.
      ENDIF.

*------------------------------------------------------------------
* Build catalog range
*------------------------------------------------------------------
      DATA(lr_catalogs) =
        VALUE /ui2/cl_tm_pb_access=>ttr_catalogs(
          FOR lv_catalog IN lt_catalogs
          (
            sign   = 'I'
            option = 'EQ'
            low    = lv_catalog
          )
        ).

*------------------------------------------------------------------
* Read ALL startup TMs once for this user
*------------------------------------------------------------------
      DATA(lo_tm_pb_access) =
        NEW /ui2/cl_tm_pb_access( ).

      mt_lookup_user_startup_tms =
        lo_tm_pb_access->get_target_mappings(
          ir_catalogs = lr_catalogs
          ir_object   = VALUE #( )
          ir_action   = VALUE #( )
          ir_tm_id    = VALUE #( )
          ir_chip_id  = VALUE #( ) ).

    ENDIF.

*--------------------------------------------------------------------
* Resolve catalog filter to actual TM-index catalog ID(s)
*--------------------------------------------------------------------
    DATA lt_tm_catalog_ids TYPE tty_tm_catalog_ids.

    IF iv_catalog_id IS NOT INITIAL.

      lt_tm_catalog_ids =
        resolve_tm_catalog_ids(
          iv_catalog_id = iv_catalog_id ).

*------------------------------------------------------------------
* Catalog was supplied but cannot be resolved in this system.
*------------------------------------------------------------------
      IF lt_tm_catalog_ids IS INITIAL.
        RETURN.
      ENDIF.

    ENDIF.

*--------------------------------------------------------------------
* Build result directly from user-specific cache
*--------------------------------------------------------------------
    CLEAR rt_tm.

    LOOP AT mt_lookup_user_startup_tms
         ASSIGNING FIELD-SYMBOL(<ls_tm>).

*------------------------------------------------------------------
* Catalog filter
*------------------------------------------------------------------
      IF iv_catalog_id IS NOT INITIAL
   AND NOT line_exists(
             lt_tm_catalog_ids[
               table_line = CONV string( <ls_tm>-catalog_id )
             ]
           ).

        CONTINUE.

      ENDIF.

*------------------------------------------------------------------
* Semantic Object filter
*------------------------------------------------------------------
      IF iv_object IS NOT INITIAL
         AND <ls_tm>-object <> iv_object.
        CONTINUE.
      ENDIF.

*------------------------------------------------------------------
* Semantic Action filter
*------------------------------------------------------------------
      IF iv_action IS NOT INITIAL
         AND <ls_tm>-action <> iv_action.
        CONTINUE.
      ENDIF.

*------------------------------------------------------------------
* Match found
*
* IMPORTANT:
* rt_tm is a sorted table, so use INSERT, not APPEND.
*------------------------------------------------------------------
      INSERT <ls_tm> INTO TABLE rt_tm.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_all_tms_for_cat_so_sa.

    rt_tm =
      lookup_all_tms(
        iv_catalog_id = iv_catalog_id
        iv_object     = iv_object
        iv_action     = iv_action ).

  ENDMETHOD.

  METHOD resolve_catalog_id.

*--------------------------------------------------------------------
* Default: unresolved
*--------------------------------------------------------------------
    CLEAR rv_catalog_id.


*--------------------------------------------------------------------
* Nothing supplied
*--------------------------------------------------------------------
    IF iv_catalog_id IS INITIAL.
      RETURN.
    ENDIF.


*--------------------------------------------------------------------
* Build catalog-key cache once per ABAP session
*--------------------------------------------------------------------
    IF mv_catalog_keys_loaded IS INITIAL.

      DATA lo_catalog_api TYPE REF TO /ui2/if_fdm_catalog_api.

      lo_catalog_api =
        NEW /ui2/cl_fdm_catalog_api(
          iv_scope                      = /ui2/if_fdm=>gc_scope-customization
          iv_include_replicated_content = abap_true ).

      mt_catalog_keys =
        lo_catalog_api->get_all_catalog_keys( ).

      mv_catalog_keys_loaded = abap_true.

    ENDIF.


*--------------------------------------------------------------------
* Convert supplied value to logical catalog ID
*
* Source may contain:
*
*   SAP_...
*   X-SAP-UI2-CATALOGPAGE:SAP_...
*   X-SAP-UI2-ADCAT:SAP_...
*
* GET_ALL_CATALOG_KEYS returns the logical ID in KEY-ID.
*--------------------------------------------------------------------
    DATA(lv_catalog_id) = CONV string( iv_catalog_id ).

    IF lv_catalog_id CP 'X-SAP-UI2-CATALOGPAGE:*'.

      REPLACE FIRST OCCURRENCE OF
        'X-SAP-UI2-CATALOGPAGE:'
        IN lv_catalog_id
        WITH ''.

    ELSEIF lv_catalog_id CP 'X-SAP-UI2-ADCAT:*'.

      REPLACE FIRST OCCURRENCE OF
        'X-SAP-UI2-ADCAT:'
        IN lv_catalog_id
        WITH ''.

    ENDIF.


*--------------------------------------------------------------------
* 1. Exact catalog ID exists
*
* TYPE (CAT/CAR) and SYSTEM_ALIAS do not matter here.
* We want the canonical logical catalog ID.
*--------------------------------------------------------------------
    LOOP AT mt_catalog_keys
      ASSIGNING FIELD-SYMBOL(<ls_catalog_key>).

      IF CONV string( <ls_catalog_key>-id ) = lv_catalog_id.

        rv_catalog_id =
          CONV /ui2/page_id( <ls_catalog_key>-id ).

        RETURN.

      ENDIF.

    ENDLOOP.


*--------------------------------------------------------------------
* 2. Try backend/replicated form
*
* Example:
*
*   SAP_TC_XYZ_APPS
*          ->
*   SAP_TC_XYZ_BE_APPS
*--------------------------------------------------------------------
    IF lv_catalog_id CP '*_APPS'
       AND lv_catalog_id NP '*_BE_APPS'.

      DATA(lv_be_catalog_id) = lv_catalog_id.

      REPLACE FIRST OCCURRENCE OF
        '_APPS'
        IN lv_be_catalog_id
        WITH '_BE_APPS'.


*------------------------------------------------------------------
* Return the actual backend catalog ID if it exists
*------------------------------------------------------------------
      LOOP AT mt_catalog_keys
        ASSIGNING <ls_catalog_key>.

        IF CONV string( <ls_catalog_key>-id ) = lv_be_catalog_id.

          rv_catalog_id =
            CONV /ui2/page_id( <ls_catalog_key>-id ).

          RETURN.

        ENDIF.

      ENDLOOP.

    ENDIF.


*--------------------------------------------------------------------
* Neither exact nor backend catalog exists
*
* rv_catalog_id remains initial.
*--------------------------------------------------------------------

  ENDMETHOD.

  METHOD resolve_tm_catalog_ids.

*--------------------------------------------------------------------
* Default: nothing resolved
*--------------------------------------------------------------------
    CLEAR rt_tm_catalog_ids.


*--------------------------------------------------------------------
* Resolve supplied/source catalog to canonical logical catalog ID
*
* Examples:
*
* SAP_A4C_BC_DEV
*   -> SAP_A4C_BC_DEV
*
* SAP_TC_CA_BP_APPS
*   -> SAP_TC_CA_BP_BE_APPS
*--------------------------------------------------------------------
    DATA(lv_resolved_catalog_id) =
      resolve_catalog_id(
        iv_catalog_id = iv_catalog_id ).

    IF lv_resolved_catalog_id IS INITIAL.
      RETURN.
    ENDIF.


*--------------------------------------------------------------------
* Ensure universal TM cache is loaded
*--------------------------------------------------------------------
    IF mv_lookup_all_tms_loaded IS INITIAL.

      DATA(lo_tm_pb_access) =
        NEW /ui2/cl_tm_pb_access( ).

      DATA(lt_all_tms) =
        lo_tm_pb_access->get_target_mappings(
          ir_catalogs = VALUE #( )
          ir_object   = VALUE #( )
          ir_action   = VALUE #( )
          ir_tm_id    = VALUE #( )
          ir_chip_id  = VALUE #( ) ).

      CLEAR mt_lookup_all_tms.

      INSERT LINES OF lt_all_tms
        INTO TABLE mt_lookup_all_tms.

      mv_lookup_all_tms_loaded = abap_true.

    ENDIF.


*--------------------------------------------------------------------
* Build the two possible TM-index representations
*
* Normal catalog:
*
*   X-SAP-UI2-CATALOGPAGE:<logical ID>
*
* Replicated catalog:
*
*   X-SAP-UI2-ADCAT:<logical ID>:<system alias>
*--------------------------------------------------------------------
    DATA(lv_resolved_id) =
      CONV string( lv_resolved_catalog_id ).

    DATA(lv_catalogpage_id) =
      |X-SAP-UI2-CATALOGPAGE:{ lv_resolved_id }|.

    DATA(lv_adcat_id) =
      |X-SAP-UI2-ADCAT:{ lv_resolved_id }|.

    DATA(lv_adcat_prefix) =
      |X-SAP-UI2-ADCAT:{ lv_resolved_id }:|.


*--------------------------------------------------------------------
* Return the ACTUAL catalog IDs contained in the TM index.
*
* Do not manufacture the system alias.
* Take the complete value directly from the TM cache.
*--------------------------------------------------------------------
    LOOP AT mt_lookup_all_tms
      ASSIGNING FIELD-SYMBOL(<ls_tm>).

      DATA(lv_tm_catalog_id) =
        CONV string( <ls_tm>-catalog_id ).

      IF lv_tm_catalog_id = lv_catalogpage_id
         OR lv_tm_catalog_id = lv_adcat_id
         OR lv_tm_catalog_id CP |{ lv_adcat_prefix }*|.

        INSERT lv_tm_catalog_id
          INTO TABLE rt_tm_catalog_ids.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD catalog_exists.

    rv_exists =
      xsdbool(
        resolve_catalog_id(
          iv_catalog_id = iv_catalog_id ) IS NOT INITIAL ).

  ENDMETHOD.


  METHOD tm_exists_in_catalog.

    IF iv_catalog_id IS INITIAL
       OR iv_semantic_object IS INITIAL
       OR iv_semantic_action IS INITIAL.

      rv_exists = abap_false.
      RETURN.

    ENDIF.

    DATA(lt_tm) =
      get_all_tms_for_cat_so_sa(
        iv_catalog_id = iv_catalog_id
        iv_object     = iv_semantic_object
        iv_action     = iv_semantic_action ).

    rv_exists =
      xsdbool( lt_tm IS NOT INITIAL ).

  ENDMETHOD.

  METHOD get_all_cat_for_so_sa.

    DATA(lt_tm_info) =
      get_all_cat_ref_for_so_sa(
        iv_object = iv_object
        iv_action = iv_action ).

    CLEAR rt_catalogs.

    LOOP AT lt_tm_info ASSIGNING FIELD-SYMBOL(<ls_tm_info>).

      IF <ls_tm_info>-catalog_id IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT VALUE ty_intent_cat(
        catalog_id = <ls_tm_info>-catalog_id )
        INTO TABLE rt_catalogs.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_all_cat_ref_for_so_sa.

*--------------------------------------------------------------------
* Read fresh TM data for the supplied Semantic Object / Action
*
* Important:
* We intentionally use the non-buffered lookup here because this method
* is supposed to provide detailed current TM/catalog/reference data.
*--------------------------------------------------------------------
    DATA(lt_tm) =
      lookup_all_tms_no_buffer(
        iv_object = iv_object
        iv_action = iv_action ).

*--------------------------------------------------------------------
* Convert SAP internal TM structure into our explicit detailed structure
*--------------------------------------------------------------------
    CLEAR rt_tm_info.

    LOOP AT lt_tm ASSIGNING FIELD-SYMBOL(<ls_tm>).

      APPEND VALUE tp_s_tm_detailed_info(
        object           = CONV string( <ls_tm>-object )
        action           = CONV string( <ls_tm>-action )
        text             = CONV string( <ls_tm>-text )
        application_type = CONV string( <ls_tm>-application_type )
        target_id        = CONV string( <ls_tm>-target_id )
        mapping_id       = CONV string( <ls_tm>-mapping_id )
        application      = <ls_tm>-application
        system_alias     = CONV string( <ls_tm>-system_alias )
        short_guid       = CONV string( <ls_tm>-short_guid )
        chip_id          = CONV string( <ls_tm>-chip_id )
        catalog_id       = CONV string( <ls_tm>-catalog_id )
        scope            = <ls_tm>-scope
        ref_chip_id      = CONV string( <ls_tm>-ref_chip_id )
        ref_catalog_id   = CONV string( <ls_tm>-ref_catalog_id )
        ref_scope        = <ls_tm>-ref_scope
        properties       = <ls_tm>-properties
        uiad_id          = <ls_tm>-uiad_id )
        TO rt_tm_info.

    ENDLOOP.

*--------------------------------------------------------------------
* Remove exact duplicates on the stable scalar identity of the TM.
*
* Do not compare APPLICATION or PROPERTIES here because they are deep
* structures/tables and are not suitable as simple dedupe keys.
*--------------------------------------------------------------------
    SORT rt_tm_info BY
      object
      action
      catalog_id
      ref_catalog_id
      chip_id
      ref_chip_id
      mapping_id
      target_id
      uiad_id.

    DELETE ADJACENT DUPLICATES FROM rt_tm_info
      COMPARING
        object
        action
        catalog_id
        ref_catalog_id
        chip_id
        ref_chip_id
        mapping_id
        target_id
        uiad_id.

  ENDMETHOD.

  METHOD get_roles_for_catalogs.

    CONSTANTS lc_catalog_prefix TYPE string VALUE 'X-SAP-UI2-CATALOGPAGE:'.

*--------------------------------------------------------------------
* Normalize and deduplicate catalog IDs
*
* /UI2/CL_PFCG_UTILS=>GET_ROLES_FOR_CATALOGS expects catalog IDs
* in FLP-internal format, for example:
*   X-SAP-UI2-CATALOGPAGE:SAP_TC_...
*--------------------------------------------------------------------
    DATA lt_catalogs TYPE /ui2/cl_pfcg_utils=>tt_catalog_ids.

    LOOP AT it_catalogs ASSIGNING FIELD-SYMBOL(<lv_catalog>).

      IF <lv_catalog> IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_catalog_id) = CONV string( <lv_catalog> ).

      IF lv_catalog_id NP 'X-SAP-UI2-CATALOGPAGE:*'
         AND lv_catalog_id NP 'X-SAP-UI2-ADCAT:*'.

        lv_catalog_id =
          lc_catalog_prefix &&
          lv_catalog_id.

      ENDIF.

      INSERT lv_catalog_id INTO TABLE lt_catalogs.

    ENDLOOP.

*--------------------------------------------------------------------
* Nothing to resolve
*--------------------------------------------------------------------
    IF lt_catalogs IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Resolve roles from catalogs using SAP standard utility
*--------------------------------------------------------------------
    /ui2/cl_pfcg_utils=>get_roles_for_catalogs(
      EXPORTING
        it_catalogs = lt_catalogs
      IMPORTING
        et_role_ids = rt_role_ids ).

*--------------------------------------------------------------------
* Defensive cleanup
*--------------------------------------------------------------------
    SORT rt_role_ids.
    DELETE ADJACENT DUPLICATES FROM rt_role_ids.

  ENDMETHOD.

  METHOD get_catalogs_for_roles.

    CLEAR rt_catalogs.

    IF it_role_ids IS INITIAL.
      RETURN.
    ENDIF.

    DATA lr_roles TYPE /ui2/cl_pfcg_utils=>tr_roles.

    lr_roles = VALUE #(
      FOR lv_role IN it_role_ids
      (
        sign   = 'I'
        option = 'EQ'
        low    = lv_role
      )
    ).

    /ui2/cl_pfcg_utils=>get_catalogs_groups_for_roles(
      EXPORTING
        ir_roles         = lr_roles
        iv_bypass_buffer = abap_false
      IMPORTING
        et_catalogs      = rt_catalogs
    ).

    SORT rt_catalogs BY role_id catalog_id.
    DELETE ADJACENT DUPLICATES FROM rt_catalogs
      COMPARING role_id catalog_id.

  ENDMETHOD.


  METHOD get_composite_roles_for_roles.

*--------------------------------------------------------------------
* Resolve composite roles for supplied single roles.
*
* This answers:
*   "In which composite roles are these roles used?"
*
* By default, SAP standard excludes composite roles with their own menu.
*--------------------------------------------------------------------
    DATA lt_role_ids TYPE /ui2/if_nwbc_runtime=>t_role_ids.

*--------------------------------------------------------------------
* Defensive cleanup of input
*--------------------------------------------------------------------
    LOOP AT it_role_ids ASSIGNING FIELD-SYMBOL(<lv_role_id>).

      IF <lv_role_id> IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND <lv_role_id> TO lt_role_ids.

    ENDLOOP.

    SORT lt_role_ids.
    DELETE ADJACENT DUPLICATES FROM lt_role_ids.

    IF lt_role_ids IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Resolve composite roles using SAP standard utility
*--------------------------------------------------------------------
    rt_composite_role_ids =
      /ui2/cl_pfcg_utils=>get_composite_roles_of_roles(
        it_role_ids                 = lt_role_ids
        iv_exclude_roles_w_own_menu = iv_exclude_roles_w_own_menu ).

*--------------------------------------------------------------------
* Defensive cleanup of result
*--------------------------------------------------------------------
    SORT rt_composite_role_ids.
    DELETE ADJACENT DUPLICATES FROM rt_composite_role_ids.

  ENDMETHOD.

  METHOD get_roles_for_so_sa.

*--------------------------------------------------------------------
* Get all detailed TM/catalog rows for the intent
*--------------------------------------------------------------------
    DATA(lt_tm_info) =
      get_all_cat_ref_for_so_sa(
        iv_object = iv_object
        iv_action = iv_action ).

*--------------------------------------------------------------------
* Collect catalogs.
*
* Important:
* For role resolution, use CATALOG_ID because that is the catalog
* which can be assigned in PFCG.
*
* REF_CATALOG_ID is the referenced/original catalog and should not be
* used here unless we explicitly want to answer a different question:
* "Which roles contain the original referenced catalog directly?"
*--------------------------------------------------------------------
    DATA lt_catalogs TYPE /ui2/cl_pfcg_utils=>tt_catalog_ids.

    LOOP AT lt_tm_info ASSIGNING FIELD-SYMBOL(<ls_tm_info>).

      IF <ls_tm_info>-catalog_id IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT CONV string( <ls_tm_info>-catalog_id )
        INTO TABLE lt_catalogs.

    ENDLOOP.

*--------------------------------------------------------------------
* Resolve roles
*--------------------------------------------------------------------
    rt_role_ids =
      get_roles_for_catalogs(
        it_catalogs = lt_catalogs ).

  ENDMETHOD.

  METHOD get_roles_of_user.

*--------------------------------------------------------------------
* Resolve user
*--------------------------------------------------------------------
    DATA(lv_user) =
      COND syuname(
        WHEN iv_user IS NOT INITIAL
        THEN iv_user
        ELSE sy-uname ).

    TRANSLATE lv_user TO UPPER CASE.

*--------------------------------------------------------------------
* Read effective PFCG roles
*--------------------------------------------------------------------
    rt_role_name =
      /ui2/cl_pfcg_utils=>get_roles_of_user(
        iv_user = lv_user ).

*--------------------------------------------------------------------
* Return each role only once
*--------------------------------------------------------------------
    SORT rt_role_name BY table_line.

    DELETE ADJACENT DUPLICATES FROM rt_role_name
      COMPARING table_line.

  ENDMETHOD.

  METHOD get_fiori_roles_of_user.

*--------------------------------------------------------------------
* Resolve user
*--------------------------------------------------------------------
    DATA(lv_user) =
      COND syuname(
        WHEN iv_user IS NOT INITIAL
        THEN iv_user
        ELSE sy-uname ).

    TRANSLATE lv_user TO UPPER CASE.

*--------------------------------------------------------------------
* Read all effective roles of the user
*--------------------------------------------------------------------
    DATA(lt_user_roles) =
      get_roles_of_user(
        iv_user = lv_user ).

    IF lt_user_roles IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Build a role range containing only the user's roles
*--------------------------------------------------------------------
    DATA lr_user_roles TYPE /ui2/cl_pfcg_utils=>tr_roles.

    lr_user_roles =
      VALUE #(
        FOR lv_role IN lt_user_roles
        (
          sign   = 'I'
          option = 'EQ'
          low    = lv_role
        )
      ).

*--------------------------------------------------------------------
* Read Fiori catalogs and legacy groups assigned to these roles
*--------------------------------------------------------------------
    DATA lt_catalogs TYPE /ui2/cl_pfcg_utils=>tt_catalogs.
    DATA lt_groups   TYPE /ui2/cl_pfcg_utils=>tt_groups.

    /ui2/cl_pfcg_utils=>get_catalogs_groups_for_roles(
      EXPORTING
        ir_roles         = lr_user_roles
        iv_bypass_buffer = abap_false
      IMPORTING
        et_catalogs      = lt_catalogs
        et_groups        = lt_groups ).

*--------------------------------------------------------------------
* Read spaces assigned to these roles
*--------------------------------------------------------------------
    DATA lt_spaces TYPE /ui2/cl_pfcg_utils=>tt_spaces.

    /ui2/cl_pfcg_utils=>get_space_for_roles(
      EXPORTING
        ir_roles         = lr_user_roles
        iv_bypass_buffer = abap_false
      IMPORTING
        et_spaces        = lt_spaces ).

*--------------------------------------------------------------------
* Build a unique set of roles containing Fiori content
*--------------------------------------------------------------------
    DATA lt_fiori_roles TYPE HASHED TABLE OF agr_name
      WITH UNIQUE KEY table_line.

    LOOP AT lt_catalogs
      ASSIGNING FIELD-SYMBOL(<ls_catalog>).

      INSERT <ls_catalog>-role_id
        INTO TABLE lt_fiori_roles.

    ENDLOOP.

    LOOP AT lt_groups
      ASSIGNING FIELD-SYMBOL(<ls_group>).

      INSERT <ls_group>-role_id
        INTO TABLE lt_fiori_roles.

    ENDLOOP.

    LOOP AT lt_spaces
      ASSIGNING FIELD-SYMBOL(<ls_space>).

      INSERT <ls_space>-role_id
        INTO TABLE lt_fiori_roles.

    ENDLOOP.

*--------------------------------------------------------------------
* Return only user roles that contain Fiori content
*--------------------------------------------------------------------
    CLEAR rt_role_name.

    LOOP AT lt_user_roles
      INTO DATA(lv_user_role).

      IF line_exists(
           lt_fiori_roles[
             table_line = lv_user_role
           ]
         ).

        APPEND lv_user_role TO rt_role_name.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* Return each role only once
*--------------------------------------------------------------------
    SORT rt_role_name BY table_line.

    DELETE ADJACENT DUPLICATES FROM rt_role_name
      COMPARING table_line.

  ENDMETHOD.

  METHOD get_user_start_up_tms.

    rt_tm =
      lookup_user_start_up_tms(
        iv_user = iv_user ).

  ENDMETHOD.

  METHOD has_start_up_tm.

    DATA(lt_tm) =
      lookup_user_start_up_tms(
        iv_user   = iv_user
        iv_object = iv_semantic_object
        iv_action = iv_semantic_action ).

    rv_found = xsdbool( lt_tm IS NOT INITIAL ).

  ENDMETHOD.

  METHOD has_tm_direct_catalog.

    DATA(lt_tm) =
      lookup_user_start_up_tms(
        iv_user       = iv_user
        iv_catalog_id = iv_catalog_id
        iv_object     = iv_semantic_object
        iv_action     = iv_semantic_action ).

    rv_found = xsdbool( lt_tm IS NOT INITIAL ).

  ENDMETHOD.

  METHOD has_tm_indirect_catalog.

*--------------------------------------------------------------------
* Resolve target catalog to actual TM-index catalog ID(s)
*--------------------------------------------------------------------
    DATA(lt_target_catalogs) =
      resolve_tm_catalog_ids(
        iv_catalog_id = iv_catalog_id ).

    IF lt_target_catalogs IS INITIAL.
      RETURN.
    ENDIF.

*--------------------------------------------------------------------
* Read startup TMs for user
*--------------------------------------------------------------------
    DATA(lt_tm) =
      lookup_user_start_up_tms(
        iv_user   = iv_user
        iv_object = iv_semantic_object
        iv_action = iv_semantic_action ).

*--------------------------------------------------------------------
* Direct catalog match?
*--------------------------------------------------------------------
    LOOP AT lt_tm ASSIGNING FIELD-SYMBOL(<tm>).

      IF line_exists(
           lt_target_catalogs[
             table_line = CONV string( <tm>-catalog_id )
           ]
         ).

        rv_found = abap_true.
        RETURN.

      ENDIF.

    ENDLOOP.

*--------------------------------------------------------------------
* Recursive search through referenced catalogs
*--------------------------------------------------------------------
    LOOP AT lt_tm ASSIGNING <tm>.

      IF <tm>-ref_catalog_id IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT lt_target_catalogs
        INTO DATA(lv_target_catalog).

        rv_found =
          search_catalog_recursive(
            iv_catalog_id      = <tm>-ref_catalog_id
            iv_target_catalog  = lv_target_catalog
            iv_semantic_object = iv_semantic_object
            iv_semantic_action = iv_semantic_action ).

        IF rv_found = abap_true.
          RETURN.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

  METHOD search_catalog_recursive.

    DATA ls_tm_dummy TYPE ty_tm.

    DATA lv_catalog_key LIKE ls_tm_dummy-catalog_id.
    DATA lv_object      LIKE ls_tm_dummy-object.
    DATA lv_action      LIKE ls_tm_dummy-action.

    FIELD-SYMBOLS <tm> TYPE ty_tm.


*--------------------------------------------------------------------
* Ensure universal TM cache is loaded
*
* search_catalog_recursive reads directly from mt_lookup_all_tms.
*--------------------------------------------------------------------
    IF mv_lookup_all_tms_loaded IS INITIAL.

      DATA(lo_tm_pb_access) =
        NEW /ui2/cl_tm_pb_access( ).

      DATA(lt_all_tms) =
        lo_tm_pb_access->get_target_mappings(
          ir_catalogs = VALUE #( )
          ir_object   = VALUE #( )
          ir_action   = VALUE #( )
          ir_tm_id    = VALUE #( )
          ir_chip_id  = VALUE #( ) ).

      CLEAR mt_lookup_all_tms.

      INSERT LINES OF lt_all_tms
        INTO TABLE mt_lookup_all_tms.

      mv_lookup_all_tms_loaded = abap_true.

    ENDIF.


*--------------------------------------------------------------------
* iv_catalog_id comes from REF_CATALOG_ID of the TM index.
*
* Therefore it is already the real TM catalog identifier, e.g.
*
* X-SAP-UI2-CATALOGPAGE:...
* or
* X-SAP-UI2-ADCAT:...:<system alias>
*
* Do not normalize or manufacture a prefix here.
*--------------------------------------------------------------------
    lv_catalog_key = iv_catalog_id.
    lv_object      = iv_semantic_object.
    lv_action      = iv_semantic_action.


*--------------------------------------------------------------------
* Target catalog reached?
*--------------------------------------------------------------------
    IF iv_catalog_id = iv_target_catalog.

      rv_found = abap_true.
      RETURN.

    ENDIF.


*--------------------------------------------------------------------
* Read matching TMs from universal in-memory cache
*--------------------------------------------------------------------
    LOOP AT mt_lookup_all_tms ASSIGNING <tm>
      USING KEY k_cat_obj_act
      WHERE catalog_id = lv_catalog_key
        AND object     = lv_object
        AND action     = lv_action.

      IF <tm>-ref_catalog_id IS INITIAL.
        CONTINUE.
      ENDIF.


*------------------------------------------------------------------
* Self-reference protection
*------------------------------------------------------------------
      IF CONV string( <tm>-ref_catalog_id ) = iv_catalog_id.
        CONTINUE.
      ENDIF.


*------------------------------------------------------------------
* DFS traversal through referenced catalog
*------------------------------------------------------------------
      rv_found =
        search_catalog_recursive(
          iv_catalog_id      = CONV string( <tm>-ref_catalog_id )
          iv_target_catalog  = iv_target_catalog
          iv_semantic_object = iv_semantic_object
          iv_semantic_action = iv_semantic_action ).

      IF rv_found = abap_true.
        RETURN.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD user_assigned_tms_for_so_sa.
    "this only works for assigned start_up
    rt_tm =
      lookup_user_start_up_tms(
        iv_user   = iv_user
        iv_object = iv_object
        iv_action = iv_action ).

  ENDMETHOD.


ENDCLASS.
