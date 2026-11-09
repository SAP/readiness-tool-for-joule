CLASS zzcl_drj_excel_proc DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_row,
        functional_area    TYPE string,
        capability_usecase TYPE string,
        api                TYPE string,
        semantic_obj_act   TYPE string,
        catalog            TYPE string,
        role               TYPE string,
        release_info       TYPE string,
        additional_info    TYPE string,
      END OF ty_row,
      tt_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY,

      BEGIN OF ty_cap_map,
        display_name TYPE string,
        cap_id       TYPE zdrj_capability-capability_name,
      END OF ty_cap_map,
      tt_cap_map TYPE HASHED TABLE OF ty_cap_map
                 WITH UNIQUE KEY display_name.

    CLASS-METHODS process
      IMPORTING
        iv_xstring   TYPE xstring
        iv_file_name TYPE string
      EXPORTING
        ev_rows      TYPE i
        ev_caps      TYPE i
        ev_scenarios TYPE i
        ev_warnings  TYPE string_table
      RAISING
        cx_sy_file_open.

  PRIVATE SECTION.

    CLASS-METHODS read_excel
      IMPORTING iv_xstring     TYPE xstring
      RETURNING VALUE(rt_rows) TYPE tt_rows.

    CLASS-METHODS normalize_to_list
      IMPORTING iv_raw         TYPE string
      RETURNING VALUE(rt_vals) TYPE string_table.

    CLASS-METHODS normalize_api_string
      IMPORTING iv_raw         TYPE string
      RETURNING VALUE(rt_vals) TYPE string_table.

    CLASS-METHODS normalize_sem_string
      IMPORTING iv_raw         TYPE string
      RETURNING VALUE(rt_vals) TYPE string_table.

    CLASS-METHODS build_and_insert
      IMPORTING it_rows      TYPE tt_rows
      EXPORTING ev_caps      TYPE i
                ev_scenarios TYPE i
                ev_warnings  TYPE string_table.
ENDCLASS.

CLASS zzcl_drj_excel_proc IMPLEMENTATION.

  METHOD process.
    DATA(lt_rows) = read_excel( iv_xstring ).
    ev_rows = lines( lt_rows ).

    DELETE FROM zdrj_capability.
    DELETE FROM zdrj_cap_brole.
    DELETE FROM zdrj_cp_scenario.
    DELETE FROM zdrj_scen_api.
    DELETE FROM zdrj_scen_tm.

    build_and_insert(
      EXPORTING it_rows      = lt_rows
      IMPORTING ev_caps      = ev_caps
                ev_scenarios = ev_scenarios
                ev_warnings  = ev_warnings ).
  ENDMETHOD.

  METHOD read_excel.
    DATA(lo_xl) = NEW cl_fdt_xl_spreadsheet(
                        document_name = `upload`
                        xdocument     = iv_xstring ).

    DATA: lt_sheet_names TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    lo_xl->if_fdt_doc_spreadsheet~get_worksheet_names(
      IMPORTING worksheet_names = lt_sheet_names ).
    " No worksheet available
    IF lt_sheet_names IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_last_sheet) = lt_sheet_names[ lines( lt_sheet_names ) ].

    DATA(lr_itab) =
      lo_xl->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
        worksheet_name = lv_last_sheet ).

    IF lr_itab IS NOT BOUND.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS:
      <lt_data>         TYPE STANDARD TABLE,
      <ls_excel_row>    TYPE any,
      <lv_excel_value>  TYPE any,
      <lv_target_value> TYPE any.

    ASSIGN lr_itab->* TO <lt_data>.

    IF <lt_data> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    DATA ls_row TYPE ty_row.

    " Row 1 contains the column headings
    LOOP AT <lt_data> ASSIGNING <ls_excel_row> FROM 2.

      CLEAR ls_row.

      " Safely copy the available Excel columns into TY_ROW.
      " Missing columns remain initial instead of causing a dump.
      DO 8 TIMES.

        UNASSIGN:
          <lv_excel_value>,
          <lv_target_value>.

        ASSIGN COMPONENT sy-index
          OF STRUCTURE <ls_excel_row>
          TO <lv_excel_value>.

        IF sy-subrc <> 0.
          EXIT.
        ENDIF.

        ASSIGN COMPONENT sy-index
          OF STRUCTURE ls_row
          TO <lv_target_value>.

        IF sy-subrc = 0.
          <lv_target_value> = CONV string( <lv_excel_value> ).
        ENDIF.

      ENDDO.

      ls_row-functional_area =
        condense( ls_row-functional_area ).

      ls_row-capability_usecase =
        condense( ls_row-capability_usecase ).

      ls_row-release_info =
        condense( ls_row-release_info ).

      IF ls_row-functional_area IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND ls_row TO rt_rows.

    ENDLOOP.
  ENDMETHOD.

  METHOD normalize_to_list.
    DATA lv_work TYPE string.
    lv_work = iv_raw.

    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_work WITH `~`.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_work WITH `~`.
    REPLACE ALL OCCURRENCES OF `,` IN lv_work WITH `~`.
    REPLACE ALL OCCURRENCES OF `;` IN lv_work WITH `~`.
    REPLACE ALL OCCURRENCES OF `|` IN lv_work WITH `~`.

    SPLIT lv_work AT `~` INTO TABLE rt_vals.

    LOOP AT rt_vals ASSIGNING FIELD-SYMBOL(<v>).
      DATA(lv_clean) = condense( <v> ).
      IF lv_clean CA ` `.
        DATA(lv_first_space) = find( val = lv_clean sub = ` ` ).
        IF lv_first_space > 0.
          DATA(lv_first_token) = substring( val = lv_clean len = lv_first_space ).
          IF lv_first_token CA `_`.
            lv_clean = lv_first_token.
          ENDIF.
        ENDIF.
      ENDIF.
      <v> = condense( lv_clean ).
    ENDLOOP.
    SORT rt_vals.
    DELETE ADJACENT DUPLICATES FROM rt_vals.
  ENDMETHOD.

  METHOD normalize_api_string.
    DATA lv_work TYPE string.
    DATA lv_token TYPE string.
    DATA lv_part TYPE string.
    DATA lv_slash_count TYPE i.
    DATA lv_len TYPE i.
    DATA lv_second_slash TYPE i.
    DATA lt_raw TYPE string_table.
    DATA lt_slash_parts TYPE string_table.

    lv_work = iv_raw.

*--------------------------------------------------------------------
* API parser rules:
*
* 1. Comma, newline, semicolon, pipe, and repeated spaces separate APIs.
* 2. Slash '/' is NOT blindly treated as a separator anymore.
* 3. Valid namespace format is only:
*      /<namespace>/<service>
*    Example:
*      /BDTS/COMMAND_SRV
*
* 4. Invalid slash examples:
*      API_SALES_ORDER_SRV/  -> becomes API_SALES_ORDER_SRV
*      /TEXT/                -> skipped, because service part is empty
*      /TEXT                 -> becomes TEXT, not treated as namespace
*      A/B                   -> treated as two dirty separated tokens A and B
*--------------------------------------------------------------------

    lv_work = replace( val  = lv_work
                       pcre = `\r\n|\n|;|\|`
                       with = `,`
                       occ  = 0 ).

    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_work WITH `,`.

    DO 5 TIMES.
      REPLACE ALL OCCURRENCES OF `  ` IN lv_work WITH `,`.
    ENDDO.

    SPLIT lv_work AT `,` INTO TABLE lt_raw.

    LOOP AT lt_raw INTO lv_token.

      lv_token = condense( lv_token ).

      IF lv_token IS INITIAL.
        CONTINUE.
      ENDIF.

      " Remove dirty Excel/pasted quote characters
      REPLACE ALL OCCURRENCES OF `"` IN lv_token WITH ``.
      REPLACE ALL OCCURRENCES OF `'` IN lv_token WITH ``.

      lv_token = condense( lv_token ).

      IF lv_token IS INITIAL.
        CONTINUE.
      ENDIF.

      TRANSLATE lv_token TO UPPER CASE.

      " Handle dirty text like: UI service UI_WHSEOUTBOUNDDELIVERYORDER
      IF lv_token CP 'UI SERVICE *'.
        REPLACE FIRST OCCURRENCE OF `UI SERVICE ` IN lv_token WITH ``.
        lv_token = condense( lv_token ).
      ENDIF.

      IF lv_token IS INITIAL.
        CONTINUE.
      ENDIF.

      " Skip version fragments like v=2 from entries such as:
      " API_BILL_OF_MATERIAL_SRV;v=2
      IF lv_token CP 'V=*'.
        CONTINUE.
      ENDIF.

      CLEAR lv_slash_count.
      FIND ALL OCCURRENCES OF `/` IN lv_token MATCH COUNT lv_slash_count.

*--------------------------------------------------------------------
* Slash handling
*--------------------------------------------------------------------
      IF lv_slash_count = 1.

        lv_len = strlen( lv_token ).

        " Dirty trailing slash:
        " API_SALES_ORDER_SRV/ -> API_SALES_ORDER_SRV
        IF lv_len > 1
           AND substring( val = lv_token off = lv_len - 1 len = 1 ) = `/`.

          lv_token = substring( val = lv_token len = lv_len - 1 ).

          " Dirty leading slash:
          " /TEXT -> TEXT
        ELSEIF lv_len > 1
           AND substring( val = lv_token off = 0 len = 1 ) = `/`.

          lv_token = substring( val = lv_token off = 1 ).

          " Single slash in middle:
          " A/B is not namespace. Treat as dirty separator.
        ELSE.

          CLEAR lt_slash_parts.
          SPLIT lv_token AT `/` INTO TABLE lt_slash_parts.

          LOOP AT lt_slash_parts INTO lv_part.
            lv_part = condense( lv_part ).

            IF lv_part IS INITIAL.
              CONTINUE.
            ENDIF.

            IF lv_part CA ` ` AND NOT lv_part CA `_`.
              CONTINUE.
            ENDIF.

            APPEND lv_part TO rt_vals.
          ENDLOOP.

          CONTINUE.

        ENDIF.

      ELSEIF lv_slash_count = 2.

        lv_len = strlen( lv_token ).

        " Valid namespace must start with /
        IF substring( val = lv_token off = 0 len = 1 ) <> `/`.
          CONTINUE.
        ENDIF.

        " Find second slash. It must not be directly after first slash
        " and it must not be the last character.
        lv_second_slash = find( val = lv_token sub = `/` off = 1 ).

        IF lv_second_slash <= 1 OR lv_second_slash >= lv_len - 1.
          CONTINUE.
        ENDIF.

      ELSEIF lv_slash_count > 2.

        " More than 2 slashes is not a supported API namespace format here.
        CONTINUE.

      ENDIF.

*--------------------------------------------------------------------
* Final validation
*--------------------------------------------------------------------
      lv_token = condense( lv_token ).

      IF lv_token IS INITIAL.
        CONTINUE.
      ENDIF.

      IF lv_token CA ` ` AND NOT lv_token CA `_`.
        CONTINUE.
      ENDIF.

      APPEND lv_token TO rt_vals.

    ENDLOOP.

    SORT rt_vals.
    DELETE ADJACENT DUPLICATES FROM rt_vals.

  ENDMETHOD.

  METHOD normalize_sem_string.
    DATA lv_work TYPE string.
    lv_work = iv_raw.

    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_work WITH ``.
    lv_work = replace( val = lv_work pcre = `\r\n|\n` with = `~` occ = 0 ).
    REPLACE ALL OCCURRENCES OF `,` IN lv_work WITH `~`.

    DATA lt_raw TYPE string_table.
    SPLIT lv_work AT `~` INTO TABLE lt_raw.

    DATA lt_clean TYPE string_table.
    LOOP AT lt_raw INTO DATA(lv_token).
      lv_token = condense( lv_token ).
      IF lv_token IS INITIAL. CONTINUE. ENDIF.
      REPLACE ALL OCCURRENCES OF ` - ` IN lv_token WITH `-`.
      REPLACE ALL OCCURRENCES OF `- `  IN lv_token WITH `-`.
      REPLACE ALL OCCURRENCES OF ` -`  IN lv_token WITH `-`.
      lv_token = condense( lv_token ).
      IF lv_token IS INITIAL. CONTINUE. ENDIF.
      APPEND lv_token TO lt_clean.
    ENDLOOP.

    DATA(lv_idx) = 0.
    DATA(lv_total) = lines( lt_clean ).
    LOOP AT lt_clean INTO DATA(lv_pair).
      lv_idx += 1.
      IF NOT lv_pair CA `-`.
        DATA(lv_next_idx) = lv_idx + 1.
        IF lv_next_idx <= lv_total.
          READ TABLE lt_clean INTO DATA(lv_next) INDEX lv_next_idx.
          IF sy-subrc = 0 AND NOT lv_next CA `-` AND NOT lv_next CA ` `.
            APPEND |{ lv_pair }-{ lv_next }| TO rt_vals.
            lv_idx += 1.
            CONTINUE.
          ENDIF.
        ENDIF.
      ENDIF.
      APPEND lv_pair TO rt_vals.
    ENDLOOP.

    DATA lt_seen   TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA lt_result TYPE string_table.
    LOOP AT rt_vals INTO DATA(lv_v).
      INSERT lv_v INTO TABLE lt_seen.
      IF sy-subrc = 0.
        APPEND lv_v TO lt_result.
      ENDIF.
    ENDLOOP.
    rt_vals = lt_result.
  ENDMETHOD.

  METHOD build_and_insert.
    DATA: lt_caps  TYPE TABLE OF zdrj_capability,
          lt_roles TYPE TABLE OF zdrj_cap_brole,
          lt_scens TYPE TABLE OF zdrj_cp_scenario,
          lt_apis  TYPE TABLE OF zdrj_scen_api,
          lt_tms   TYPE TABLE OF zdrj_scen_tm.

    DATA: lt_cap_map      TYPE tt_cap_map.
    DATA: lt_unique_areas TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT it_rows INTO DATA(ls_row).
      TRY.
          INSERT ls_row-functional_area INTO TABLE lt_unique_areas.
        CATCH cx_sy_itab_duplicate_key.
      ENDTRY.
    ENDLOOP.

    DATA(lv_cap_seq) = 0.
    LOOP AT lt_unique_areas INTO DATA(lv_area).
      lv_cap_seq += 1.
      DATA(lv_cap_id) = |CAP-{ lv_cap_seq WIDTH = 3 ALIGN = RIGHT PAD = '0' }|.
      INSERT VALUE #( display_name = lv_area  cap_id = lv_cap_id )
             INTO TABLE lt_cap_map.
      APPEND VALUE #(
        capability_name        = lv_cap_id
        capability_displayname = CONV #( lv_area )
      ) TO lt_caps.
    ENDLOOP.
    ev_caps = lv_cap_seq.

    " --- Pre-collect all unique API names for bulk DB lookup ---
    DATA lt_all_apis TYPE TABLE OF string WITH EMPTY KEY.
    LOOP AT it_rows INTO DATA(ls_pre).
      LOOP AT normalize_api_string( ls_pre-api ) INTO DATA(lv_pre_api).
        APPEND lv_pre_api TO lt_all_apis.
      ENDLOOP.
    ENDLOOP.
    SORT lt_all_apis BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_all_apis COMPARING table_line.

    " Bulk fetch V2 services
    " Excel/API input is checked exactly as parsed.
    " For V2, check:
    " 1. /IWFND/I_MED_SRH-OBJECT_NAME
    " 2. /IWBEP/I_MGW_SRH-TECHNICAL_NAME
    " If either table contains the API, it is treated as V2.

    DATA lt_v2_apis TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    DATA lt_api_object_names TYPE TABLE OF /iwfnd/i_med_srh-object_name WITH EMPTY KEY.
    lt_api_object_names = VALUE #( FOR ls_api IN lt_all_apis ( CONV #( ls_api ) ) ).

    DATA lt_api_technical_names TYPE TABLE OF /iwbep/i_mgw_srh-technical_name WITH EMPTY KEY.
    lt_api_technical_names = VALUE #( FOR ls_api IN lt_all_apis ( CONV #( ls_api ) ) ).

    IF lt_api_object_names IS NOT INITIAL.

      SELECT object_name
        FROM /iwfnd/i_med_srh
        INTO TABLE @DATA(lt_v2_iwfnd)
        FOR ALL ENTRIES IN @lt_api_object_names
        WHERE object_name = @lt_api_object_names-table_line.

      LOOP AT lt_v2_iwfnd INTO DATA(lv_object_name).
        INSERT CONV string( lv_object_name ) INTO TABLE lt_v2_apis.
      ENDLOOP.

    ENDIF.

    IF lt_api_technical_names IS NOT INITIAL.

      SELECT technical_name
        FROM /iwbep/i_mgw_srh
        INTO TABLE @DATA(lt_v2_iwbep)
        FOR ALL ENTRIES IN @lt_api_technical_names
        WHERE technical_name = @lt_api_technical_names-table_line.

      LOOP AT lt_v2_iwbep INTO DATA(lv_technical_name).
        INSERT CONV string( lv_technical_name ) INTO TABLE lt_v2_apis.
      ENDLOOP.

    ENDIF.


    " Bulk fetch V4 service groups
    "
    " Check all relevant V4 registries:
    " 1. /IWFND/C_V4_MSGR - Published V4 service groups
    " 2. /IWBEP/I_V4_MSGR - Registered V4 service groups
    " 3. /IWBEP/I_V4_MSGA - V4 service group assignments
    "
    " A match in ANY of these tables means the API is treated as V4.

    DATA lt_v4_group_ids TYPE TABLE OF /iwfnd/c_v4_msgr-group_id WITH EMPTY KEY.

    DATA lt_v4_api_names TYPE TABLE OF /iwfnd/c_v4_msgr-group_id WITH EMPTY KEY.

    lt_v4_api_names =
      VALUE #( FOR ls IN lt_all_apis
               ( CONV #( ls ) ) ).

    IF lt_v4_api_names IS NOT INITIAL.

      " Published V4 service groups
      SELECT group_id
        FROM /iwfnd/c_v4_msgr
        INTO TABLE @lt_v4_group_ids
        FOR ALL ENTRIES IN @lt_v4_api_names
        WHERE group_id = @lt_v4_api_names-table_line.

      " Registered V4 service groups
      SELECT group_id
        FROM /iwbep/i_v4_msgr
        APPENDING TABLE @lt_v4_group_ids
        FOR ALL ENTRIES IN @lt_v4_api_names
        WHERE group_id = @lt_v4_api_names-table_line.

      " V4 service group assignments
      SELECT group_id
        FROM /iwbep/i_v4_msga
        APPENDING TABLE @lt_v4_group_ids
        FOR ALL ENTRIES IN @lt_v4_api_names
        WHERE group_id = @lt_v4_api_names-table_line.

    ENDIF.

    SORT lt_v4_group_ids BY table_line.
    DELETE ADJACENT DUPLICATES FROM lt_v4_group_ids COMPARING table_line.

    DATA: lt_role_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA: lt_api_seen  TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    TYPES:
      BEGIN OF ty_catalog_validity,
        catalog_id TYPE string,
        exists     TYPE abap_bool,
      END OF ty_catalog_validity.

    DATA lt_catalog_validity
      TYPE HASHED TABLE OF ty_catalog_validity
      WITH UNIQUE KEY catalog_id.

    DATA lt_all_catalogs
      TYPE SORTED TABLE OF string
      WITH UNIQUE KEY table_line.

    DATA lt_known_sem_objects
      TYPE HASHED TABLE OF string
      WITH UNIQUE KEY table_line.

    DATA lt_known_sem_actions
      TYPE HASHED TABLE OF string
      WITH UNIQUE KEY table_line.

*--------------------------------------------------------------------
* Pre-collect and validate unique catalogs
*--------------------------------------------------------------------
    LOOP AT it_rows INTO DATA(ls_catalog_pre).

      LOOP AT normalize_to_list( ls_catalog_pre-catalog )
          INTO DATA(lv_catalog_pre).

        lv_catalog_pre = condense( lv_catalog_pre ).

        IF lv_catalog_pre IS INITIAL.
          CONTINUE.
        ENDIF.

        INSERT lv_catalog_pre INTO TABLE lt_all_catalogs.

      ENDLOOP.

    ENDLOOP.

    LOOP AT lt_all_catalogs INTO DATA(lv_catalog_check).

      DATA(lv_catalog_exists) =
        zcl_drj_flp_start_up_utility=>catalog_exists(
          iv_catalog_id = CONV /ui2/page_id( lv_catalog_check ) ).

      INSERT VALUE ty_catalog_validity(
        catalog_id = lv_catalog_check
        exists     = lv_catalog_exists
      ) INTO TABLE lt_catalog_validity.

    ENDLOOP.

*--------------------------------------------------------------------
* Build Semantic Object / Action lookup from system Target Mappings
*--------------------------------------------------------------------
    DATA(lt_all_system_tms) =
      zcl_drj_flp_start_up_utility=>lookup_all_tms( ).

    LOOP AT lt_all_system_tms ASSIGNING FIELD-SYMBOL(<ls_system_tm>).

      IF <ls_system_tm>-object IS NOT INITIAL.
        INSERT CONV string( <ls_system_tm>-object )
          INTO TABLE lt_known_sem_objects.
      ENDIF.

      IF <ls_system_tm>-action IS NOT INITIAL.
        INSERT CONV string( <ls_system_tm>-action )
          INTO TABLE lt_known_sem_actions.
      ENDIF.

    ENDLOOP.

    DATA(lv_scen_seq) = 0.

    LOOP AT it_rows INTO ls_row.
      READ TABLE lt_cap_map INTO DATA(ls_cap)
           WITH TABLE KEY display_name = ls_row-functional_area.
      DATA(lv_cap_id_cur) = ls_cap-cap_id.

      READ TABLE lt_caps ASSIGNING FIELD-SYMBOL(<ls_cap_rec>)
           WITH KEY capability_name = lv_cap_id_cur.
      IF sy-subrc = 0 AND ls_row-release_info IS NOT INITIAL.
        <ls_cap_rec>-release_info = CONV #( ls_row-release_info ).
      ENDIF.

      lv_scen_seq += 1.
      DATA(lv_scen_id) = |SCEN-{ lv_scen_seq WIDTH = 4 ALIGN = RIGHT PAD = '0' }|.

      DATA(lv_scen_desc) = ls_row-capability_usecase.
      IF ls_row-additional_info IS NOT INITIAL.
        lv_scen_desc = |{ lv_scen_desc } [{ ls_row-additional_info }]|.
      ENDIF.

      APPEND VALUE #(
        capability_name      = lv_cap_id_cur
        scenario_name        = lv_scen_id
        scenario_description = CONV #( lv_scen_desc )
        namespace            = CONV #( ls_row-functional_area )
      ) TO lt_scens.

      " Col C → APIs with version detection
      DATA(lt_apis_found) = normalize_api_string( ls_row-api ).
      IF ls_row-api IS NOT INITIAL AND lt_apis_found IS INITIAL.
        APPEND |[API] '{ ls_row-functional_area }' / '{ ls_row-capability_usecase }': could not parse APIs from: { ls_row-api }|
          TO ev_warnings.
      ENDIF.

      LOOP AT lt_apis_found INTO DATA(lv_api).
        DATA(lv_api_key) = lv_cap_id_cur && `||` && lv_scen_id && `||` && lv_api.
        INSERT lv_api_key INTO TABLE lt_api_seen.
        IF sy-subrc = 0.

          " Determine API version using pre-fetched results
          DATA lv_api_version TYPE zdrj_scen_api-api_version.
          DATA lv_api_exists  TYPE abap_bool.

          CLEAR lv_api_exists.

          IF line_exists( lt_v2_apis[ table_line = lv_api ] ).

            lv_api_version = 'V2'.
            lv_api_exists  = abap_true.

          ELSEIF line_exists( lt_v4_group_ids[ table_line = CONV /iwfnd/c_v4_msgr-group_id( lv_api ) ] ).

            lv_api_version = 'V4'.
            lv_api_exists  = abap_true.

          ELSE.

            lv_api_version = 'UNKNOWN'.
            lv_api_exists  = abap_false.

            APPEND |[API-VER] '{ ls_row-functional_area }' / '{ ls_row-capability_usecase }': service '{ lv_api }' not found in V2 or V4 registry|
              TO ev_warnings.

          ENDIF.

          APPEND VALUE #(
            capability_name    = lv_cap_id_cur
            scenario_name      = lv_scen_id
            odata_service_name = CONV #( lv_api )
            api_version        = lv_api_version
            api_exists         = lv_api_exists
          ) TO lt_apis.

        ENDIF.
      ENDLOOP.

      " Col D + Col E → Target Mappings
      DATA(lt_sem_pairs) = normalize_sem_string( ls_row-semantic_obj_act ).
      DATA(lt_catalogs)  = normalize_to_list( ls_row-catalog ).

      IF ls_row-semantic_obj_act IS NOT INITIAL AND lt_sem_pairs IS INITIAL.
        APPEND |[TM] '{ ls_row-functional_area }' / '{ ls_row-capability_usecase }': no valid SemanticObject-Action pairs found in: { ls_row-semantic_obj_act }|
          TO ev_warnings.
      ENDIF.

      LOOP AT lt_sem_pairs INTO DATA(lv_pair).
        DATA(lv_dash) = find( val = lv_pair sub = `-` occ = 1 ).
        IF lv_dash <= 0.
          APPEND |[TM] '{ ls_row-functional_area }' / '{ ls_row-capability_usecase }': token '{ lv_pair }' has no SemanticObject-Action separator|
            TO ev_warnings.
        ENDIF.

        DATA(lv_sem_obj) = COND string(
          WHEN lv_dash > 0 THEN substring( val = lv_pair len = lv_dash )
          ELSE lv_pair ).
        DATA(lv_sem_act) = COND string(
          WHEN lv_dash > 0 THEN substring( val = lv_pair off = lv_dash + 1 )
          ELSE `` ).

        lv_sem_obj = condense( lv_sem_obj ).
        lv_sem_act = condense( lv_sem_act ).
        IF lv_sem_obj IS INITIAL. CONTINUE. ENDIF.

        DATA(lv_sem_obj_exists) =
          xsdbool(
            line_exists(
              lt_known_sem_objects[ table_line = lv_sem_obj ] ) ).

        DATA(lv_sem_act_exists) =
          xsdbool(
            line_exists(
              lt_known_sem_actions[ table_line = lv_sem_act ] ) ).

        IF lt_catalogs IS INITIAL.
          APPEND VALUE #(
            capability_name        = lv_cap_id_cur
            scenario_name          = lv_scen_id
            semantic_object        = CONV #( lv_sem_obj )
            semantic_action        = CONV #( lv_sem_act )
            catalog_id             = ``
            semantic_object_exists = lv_sem_obj_exists
            semantic_action_exists = lv_sem_act_exists
            catalog_exists         = abap_false
            tm_exists_in_catalog   = abap_false
          ) TO lt_tms.

        ELSE.

          LOOP AT lt_catalogs INTO DATA(lv_cat).

            lv_cat = condense( lv_cat ).

            READ TABLE lt_catalog_validity
  ASSIGNING FIELD-SYMBOL(<ls_catalog_validity>)
  WITH TABLE KEY catalog_id = lv_cat.

            DATA(lv_cat_exists) =
  COND abap_bool(
    WHEN sy-subrc = 0
    THEN <ls_catalog_validity>-exists
    ELSE abap_false ).

            DATA(lv_tm_exists_in_catalog) = abap_false.

            IF lv_cat_exists = abap_true.

              lv_tm_exists_in_catalog =
                zcl_drj_flp_start_up_utility=>tm_exists_in_catalog(
                  iv_catalog_id      = CONV /ui2/page_id( lv_cat )
                  iv_semantic_object = CONV /ui2/semantic_object( lv_sem_obj )
                  iv_semantic_action = CONV /ui2/semantic_action( lv_sem_act ) ).

            ENDIF.

            IF lv_cat_exists = abap_false.

              APPEND
                |[CATALOG] '{ ls_row-functional_area }' / '{ ls_row-capability_usecase }': catalog '{ lv_cat }' not found in system for Target Mapping '{ lv_sem_obj }-{ lv_sem_act }'|
                TO ev_warnings.

            ELSEIF lv_tm_exists_in_catalog = abap_false.

              APPEND
                |[CATALOG-TM] '{ ls_row-functional_area }' / '{ ls_row-capability_usecase }': catalog '{ lv_cat }' exists but does not contain Target Mapping '{ lv_sem_obj }-{ lv_sem_act }'|
                TO ev_warnings.

            ENDIF.
            APPEND VALUE #(
              capability_name        = lv_cap_id_cur
              scenario_name          = lv_scen_id
              semantic_object        = CONV #( lv_sem_obj )
              semantic_action        = CONV #( lv_sem_act )
              catalog_id             = CONV #( lv_cat )
              semantic_object_exists = lv_sem_obj_exists
              semantic_action_exists = lv_sem_act_exists
              catalog_exists         = lv_cat_exists
              tm_exists_in_catalog   = lv_tm_exists_in_catalog
          ) TO lt_tms.

          ENDLOOP.
        ENDIF.
      ENDLOOP.

      " Col F → Business Roles
      LOOP AT normalize_to_list( ls_row-role ) INTO DATA(lv_role).

        lv_role = condense( lv_role ).
        TRANSLATE lv_role TO UPPER CASE.

        IF lv_role IS INITIAL.
          CONTINUE.
        ENDIF.

        " Ignore descriptive text such as years, FPS notes, SAP Note text, etc.
        " Only role-like tokens containing '_' are stored.
        IF NOT lv_role CA `_`.
          CONTINUE.
        ENDIF.

        DATA(lv_role_key) = lv_cap_id_cur && `||` && lv_role.

        INSERT lv_role_key INTO TABLE lt_role_seen.

        IF sy-subrc = 0.
          APPEND VALUE #(
            capability_name = lv_cap_id_cur
            business_role   = CONV #( lv_role )
          ) TO lt_roles.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

    ev_scenarios = lv_scen_seq.

    SORT lt_tms BY
  capability_name
  scenario_name
  semantic_object
  semantic_action
  catalog_id.

    DELETE ADJACENT DUPLICATES FROM lt_tms
      COMPARING
        capability_name
        scenario_name
        semantic_object
        semantic_action
        catalog_id.

    INSERT zdrj_capability FROM TABLE @lt_caps.
    INSERT zdrj_cap_brole  FROM TABLE @lt_roles.
    INSERT zdrj_cp_scenario    FROM TABLE @lt_scens.
    INSERT zdrj_scen_api   FROM TABLE @lt_apis.
    INSERT zdrj_scen_tm    FROM TABLE @lt_tms.
  ENDMETHOD.

ENDCLASS.

