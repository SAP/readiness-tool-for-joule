*&---------------------------------------------------------------------*
*& Report ZDR_JOULE_DATA_CLEANUP
*& Readiness Inspection and Guidance Tool for Joule Scenarios
*& Clear selected application database tables (with simulation).
*& All selection texts are defined in this source; no text elements.
*&---------------------------------------------------------------------*
REPORT zdr_joule_data_cleanup LINE-SIZE 160.

TYPES:
  BEGIN OF ty_table,
    tabname       TYPE tabname,
    description   TYPE c LENGTH 48,
    selected      TYPE abap_bool,
    count_before  TYPE int8,
    count_changed TYPE int8,
  END OF ty_table.

DATA:
  gt_tables        TYPE STANDARD TABLE OF ty_table WITH EMPTY KEY,
  gv_selected      TYPE i,
  gv_total_before  TYPE int8,
  gv_total_changed TYPE int8,
  gv_mode          TYPE c LENGTH 25,
  gv_col_heading   TYPE c LENGTH 18,
  gv_status        TYPE c LENGTH 90,
  gv_error         TYPE string.

*-----------------------------------------------------------------------
* Selection screen: only local variables and inline labels are used.
*-----------------------------------------------------------------------
SELECTION-SCREEN BEGIN OF BLOCK bcap WITH FRAME TITLE gvhcap.
PARAMETERS:
  p_cap  AS CHECKBOX DEFAULT space,
  p_brol AS CHECKBOX DEFAULT space,
  p_cpsc AS CHECKBOX DEFAULT space,
  p_api  AS CHECKBOX DEFAULT space,
  p_tm   AS CHECKBOX DEFAULT space.
SELECTION-SCREEN END OF BLOCK bcap.

SELECTION-SCREEN BEGIN OF BLOCK bcra WITH FRAME TITLE gvhcra.
PARAMETERS:
  p_hdr  AS CHECKBOX DEFAULT space,
  p_role AS CHECKBOX DEFAULT space,
  p_res  AS CHECKBOX DEFAULT space,
  p_miss AS CHECKBOX DEFAULT space.
SELECTION-SCREEN END OF BLOCK bcra.

SELECTION-SCREEN BEGIN OF BLOCK blog WITH FRAME TITLE gvhlog.
PARAMETERS p_log AS CHECKBOX DEFAULT space.
SELECTION-SCREEN END OF BLOCK blog.

SELECTION-SCREEN BEGIN OF BLOCK brun WITH FRAME TITLE gvhrun.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT /1(75) gv_hint.
SELECTION-SCREEN END OF BLOCK brun.

INITIALIZATION.
  gvhcap = 'Capability and Scenario Data (5 tables)'.
  gvhcra = 'Custom Role Analyser Data (4 tables)'.
  gvhlog = 'Import History (1 table)'.
  gvhrun = 'Execution Mode'.
  gv_hint     = 'Untick Simulation Mode to delete data permanently (confirmation required).'.

  %_p_cap_%_app_%-text  = 'ZDRJ_CAPABILITY - Capabilities'.
  %_p_brol_%_app_%-text = 'ZDRJ_CAP_BROLE - Roles'.
  %_p_cpsc_%_app_%-text = 'ZDRJ_CP_SCENARIO - Scenarios'.
  %_p_api_%_app_%-text  = 'ZDRJ_SCEN_API - APIs'.
  %_p_tm_%_app_%-text   = 'ZDRJ_SCEN_TM - Mappings'.
  %_p_hdr_%_app_%-text  = 'ZDRJ_CRA_HDR - Headers'.
  %_p_role_%_app_%-text = 'ZDRJ_CRA_ROLE - Roles'.
  %_p_res_%_app_%-text  = 'ZDRJ_CRA_RESULT - Results'.
  %_p_miss_%_app_%-text = 'ZDRJ_CRA_MISSING - Missing'.
  %_p_log_%_app_%-text  = 'ZZDRJ_IMPORT_LOG - Import Log'.
  %_p_test_%_app_%-text = 'Simulation Mode - No Changes'.

START-OF-SELECTION.
  PERFORM prepare_tables.

  IF gv_selected = 0.
    MESSAGE 'Please select at least one table.' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "Read existing records first. Do not delete if any count fails.
  PERFORM count_records.
  IF gv_error IS NOT INITIAL.
    MESSAGE gv_error TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF p_test = abap_true.
    gv_mode          = 'SIMULATION'.
    gv_col_heading   = 'Would Delete'.
    gv_status        = 'Simulation only: no database changes were made.'.
    gv_total_changed = gv_total_before.
    LOOP AT gt_tables ASSIGNING FIELD-SYMBOL(<ls_test>)
         WHERE selected = abap_true.
      <ls_test>-count_changed = <ls_test>-count_before.
    ENDLOOP.
  ELSE.
    "The confirmation popup is intentionally limited to dialog runs.
    IF sy-batch = abap_true.
      MESSAGE 'Actual deletion must be run in dialog, not background.'
        TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA lv_answer TYPE c LENGTH 1.
    DATA lv_question TYPE c LENGTH 200.
    lv_question = |Permanently delete { gv_total_before } records | &&
                  |from { gv_selected } selected table(s)?|.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Confirm Joule Data Deletion'
        text_question         = lv_question
        text_button_1         = 'Delete Data'
        text_button_2         = 'Cancel'
        default_button        = '2'
        display_cancel_button = 'X'
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        OTHERS                = 1.

    gv_mode        = 'ACTUAL DELETION'.
    gv_col_heading = 'Deleted'.

    IF sy-subrc <> 0 OR lv_answer <> '1'.
      gv_status = 'Cancelled: no database changes were made.'.
    ELSE.
      PERFORM delete_records.
    ENDIF.
  ENDIF.

  PERFORM display_results.

*-----------------------------------------------------------------------
* Fixed allowlist of all ten tables shown in the package screenshots.
* Order: child/detail data before parent/master data.
*-----------------------------------------------------------------------
FORM prepare_tables.
  "Custom Role Analyser: details before header
  APPEND VALUE #( tabname = 'ZDRJ_CRA_MISSING'
                  description = 'Custom Role Analysis Missing Requirements'
                  selected = p_miss ) TO gt_tables.
  APPEND VALUE #( tabname = 'ZDRJ_CRA_RESULT'
                  description = 'Custom Role Analysis Results'
                  selected = p_res ) TO gt_tables.
  APPEND VALUE #( tabname = 'ZDRJ_CRA_ROLE'
                  description = 'Custom Role Analysis Roles'
                  selected = p_role ) TO gt_tables.
  APPEND VALUE #( tabname = 'ZDRJ_CRA_HDR'
                  description = 'Custom Role Analysis Header'
                  selected = p_hdr ) TO gt_tables.

  "Capability data: scenario details before master records
  APPEND VALUE #( tabname = 'ZDRJ_SCEN_API'
                  description = 'Joule Scenario APIs'
                  selected = p_api ) TO gt_tables.
  APPEND VALUE #( tabname = 'ZDRJ_SCEN_TM'
                  description = 'Joule Scenario Target Mappings'
                  selected = p_tm ) TO gt_tables.
  APPEND VALUE #( tabname = 'ZDRJ_CP_SCENARIO'
                  description = 'Joule Capability Scenarios'
                  selected = p_cpsc ) TO gt_tables.
  APPEND VALUE #( tabname = 'ZDRJ_CAP_BROLE'
                  description = 'Joule Capability Business Roles'
                  selected = p_brol ) TO gt_tables.
  APPEND VALUE #( tabname = 'ZDRJ_CAPABILITY'
                  description = 'Joule Capabilities'
                  selected = p_cap ) TO gt_tables.

  "Import history
  APPEND VALUE #( tabname = 'ZZDRJ_IMPORT_LOG'
                  description = 'Joule Import Log'
                  selected = p_log ) TO gt_tables.

  LOOP AT gt_tables TRANSPORTING NO FIELDS
       WHERE selected = abap_true.
    gv_selected = gv_selected + 1.
  ENDLOOP.
ENDFORM.

*-----------------------------------------------------------------------
* Count all selected tables. Dynamic names come ONLY from the fixed list.
*-----------------------------------------------------------------------
FORM count_records.
  LOOP AT gt_tables ASSIGNING FIELD-SYMBOL(<ls_table>)
       WHERE selected = abap_true.
    DATA(lv_table) = <ls_table>-tabname.
    TRY.
        SELECT COUNT( * ) FROM (lv_table)
          INTO @<ls_table>-count_before.
      CATCH cx_root INTO DATA(lx_count).
        gv_error = |Could not read { lv_table }: { lx_count->get_text( ) }|.
        RETURN.
    ENDTRY.
    gv_total_before = gv_total_before + <ls_table>-count_before.
  ENDLOOP.
ENDFORM.

*-----------------------------------------------------------------------
* One transaction. If a DELETE raises an exception, roll everything back.
*-----------------------------------------------------------------------
FORM delete_records.
  TRY.
      LOOP AT gt_tables ASSIGNING FIELD-SYMBOL(<ls_table>)
           WHERE selected = abap_true.
        DATA(lv_table) = <ls_table>-tabname.
        IF <ls_table>-count_before = 0.
          CONTINUE.
        ENDIF.

        DELETE FROM (lv_table).
        <ls_table>-count_changed = sy-dbcnt.
        gv_total_changed = gv_total_changed + <ls_table>-count_changed.
      ENDLOOP.

      COMMIT WORK AND WAIT.
      gv_status = 'Deletion completed and committed successfully.'.

    CATCH cx_root INTO DATA(lx_delete).
      ROLLBACK WORK.
      gv_error = lx_delete->get_text( ).
      gv_status = 'Deletion failed: transaction rolled back; no changes saved.'.
      gv_total_changed = 0.
      LOOP AT gt_tables ASSIGNING FIELD-SYMBOL(<ls_reset>).
        CLEAR <ls_reset>-count_changed.
      ENDLOOP.
  ENDTRY.
ENDFORM.

*-----------------------------------------------------------------------
* Plain ABAP list; works directly in SE38 with no extra objects.
*-----------------------------------------------------------------------
FORM display_results.
  SKIP.
  WRITE: / 'READINESS INSPECTION AND GUIDANCE TOOL FOR JOULE SCENARIOS'.
  WRITE: / 'Application Table Data Cleanup'.
  ULINE.
  WRITE: / 'Client:', sy-mandt,
           28 'Mode:', gv_mode,
           65 'Selected tables:', gv_selected.
  WRITE: / gv_status.
  IF gv_error IS NOT INITIAL.
    WRITE: / 'Error:', gv_error.
  ENDIF.
  SKIP.
  WRITE: / 'Table', 26 'Description',
           90 'Before', 112 gv_col_heading.
  ULINE.

  LOOP AT gt_tables INTO DATA(ls_table) WHERE selected = abap_true.
    WRITE: / ls_table-tabname,
             26 ls_table-description,
             90 ls_table-count_before,
             112 ls_table-count_changed.
  ENDLOOP.

  ULINE.
  WRITE: / 'TOTAL',
           90 gv_total_before,
           112 gv_total_changed.
  SKIP.
  IF p_test = abap_true.
    WRITE: / 'The totals are simulated; all database records remain unchanged.'.
  ELSEIF gv_error IS NOT INITIAL.
    WRITE: / 'Deletion failed and was rolled back. The Deleted total is 0.'.
  ELSEIF gv_status CS 'Cancelled'.
    WRITE: / 'Deletion was cancelled. The Deleted total is 0.'.
  ELSE.
    WRITE: / 'Deleted counts are the actual SQL affected-row counts.'.
  ENDIF.
ENDFORM.
