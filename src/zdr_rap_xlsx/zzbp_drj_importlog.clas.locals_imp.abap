CLASS lhc_importlog DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR importlog RESULT result.
    METHODS import_excel FOR MODIFY
      IMPORTING keys FOR ACTION importlog~import_excel.
    METHODS export_excel FOR MODIFY
      IMPORTING keys   FOR ACTION importlog~export_excel
      RESULT    result.
    METHODS import_scenarios_excel FOR MODIFY
      IMPORTING keys FOR ACTION importlog~import_scenarios_excel.
ENDCLASS.

CLASS lhc_importlog IMPLEMENTATION.
  METHOD get_global_authorizations.

    IF requested_authorizations-%action-import_excel = if_abap_behv=>mk-on.
      result-%action-import_excel = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-export_excel = if_abap_behv=>mk-on.
      result-%action-export_excel = if_abap_behv=>auth-allowed.
    ENDIF.

    IF requested_authorizations-%action-import_scenarios_excel = if_abap_behv=>mk-on.
      result-%action-import_scenarios_excel = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.

  METHOD import_excel.
    DATA(ls_param) = keys[ 1 ]-%param.

    DATA lv_content TYPE string.
    lv_content = ls_param-file_content.

    FIND REGEX '^data:[^;]+;base64,' IN lv_content.
    IF sy-subrc = 0.
      REPLACE REGEX '^data:[^;]+;base64,' IN lv_content WITH ``.
    ENDIF.

    DATA lv_xstring TYPE xstring.
    CALL FUNCTION 'SCMS_BASE64_DECODE_STR'
      EXPORTING
        input  = lv_content
      IMPORTING
        output = lv_xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.

    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    DATA lv_uuid TYPE sysuuid_x16.
    TRY.
        lv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
    ENDTRY.

    DATA lv_imported_by TYPE zzdrj_import_log-imported_by.
    lv_imported_by = sy-uname.

    TRY.
        zzcl_drj_excel_proc=>process(
          EXPORTING
            iv_xstring   = lv_xstring
            iv_file_name = CONV string( ls_param-file_name )
          IMPORTING
            ev_rows      = DATA(lv_rows)
            ev_caps      = DATA(lv_caps)
            ev_scenarios = DATA(lv_scens)
            ev_warnings  = DATA(lt_warnings) ).

        " Build message from warnings
        DATA(lv_status) = COND string(
          WHEN lt_warnings IS INITIAL THEN 'SUCCESS'
          ELSE 'WARNING' ).

        DATA lv_message TYPE string.
        LOOP AT lt_warnings INTO DATA(lv_warn).
          lv_message = |{ lv_message }{ lv_warn }\n|.
        ENDLOOP.

        INSERT INTO zzdrj_import_log VALUES @(
          VALUE #(
            import_uuid       = lv_uuid
            import_ts         = lv_ts
            imported_by       = lv_imported_by
            file_name         = ls_param-file_name
            rows_in_file      = lv_rows
            caps_created      = lv_caps
            scenarios_created = lv_scens
            warnings_count    = lines( lt_warnings )
            status            = lv_status
            message           = lv_message ) ).

      CATCH cx_root INTO DATA(lx).
        INSERT INTO zzdrj_import_log VALUES @(
          VALUE #(
            import_uuid       = lv_uuid
            import_ts         = lv_ts
            imported_by       = lv_imported_by
            file_name         = ls_param-file_name
            rows_in_file      = 0
            caps_created      = 0
            scenarios_created = 0
            warnings_count    = 0
            status            = 'ERROR'
            message           = lx->get_text( ) ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD export_excel.

    DATA lv_xstring TYPE xstring.
    DATA lv_rows    TYPE i.
    DATA lv_base64  TYPE string.

    zzcl_drj_excel_export=>export(
      IMPORTING
        ev_xstring = lv_xstring
        ev_rows    = lv_rows ).

    CALL FUNCTION 'SCMS_BASE64_ENCODE_STR'
      EXPORTING
        input  = lv_xstring
      IMPORTING
        output = lv_base64.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).

      APPEND VALUE #(
        %cid = <ls_key>-%cid
        %param = VALUE #(
          file_content  = lv_base64
          file_name     = |Joule_Capabilities_Export_{ sy-datum }_{ sy-uzeit }.xlsx|
          mime_type     = `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
          rows_exported = lv_rows
        )
      ) TO result.

    ENDLOOP.

  ENDMETHOD.

    METHOD import_scenarios_excel.

    DATA(ls_param) = keys[ 1 ]-%param.

    DATA lv_content TYPE string.

    lv_content = ls_param-file_content.

    FIND REGEX '^data:[^;]+;base64,' IN lv_content.

    IF sy-subrc = 0.

      REPLACE REGEX '^data:[^;]+;base64,' IN lv_content WITH ``.

    ENDIF.


    DATA lv_xstring TYPE xstring.

    CALL FUNCTION 'SCMS_BASE64_DECODE_STR'
      EXPORTING
        input  = lv_content
      IMPORTING
        output = lv_xstring
      EXCEPTIONS
        failed = 1
        OTHERS = 2.


    DATA lv_ts TYPE timestampl.

    GET TIME STAMP FIELD lv_ts.


    DATA lv_uuid TYPE sysuuid_x16.

    TRY.

        lv_uuid = cl_system_uuid=>create_uuid_x16_static( ).

      CATCH cx_uuid_error.

    ENDTRY.


    DATA lv_imported_by TYPE zzdrj_import_log-imported_by.

    lv_imported_by = sy-uname.


    TRY.

        zzcl_drj_scen_excel_proc=>process(
          EXPORTING
            iv_xstring   = lv_xstring
            iv_file_name = CONV string( ls_param-file_name )
          IMPORTING
            ev_rows      = DATA(lv_rows)
            ev_scenarios = DATA(lv_scens)
            ev_tms       = DATA(lv_tms)
            ev_warnings  = DATA(lt_warnings) ).


        DATA(lv_status) = COND string(
          WHEN lt_warnings IS INITIAL THEN 'SUCCESS'
          ELSE 'WARNING' ).


        " One dummy capability is created only when scenarios
        " were successfully prepared/persisted.
        DATA(lv_caps) = COND i(
          WHEN lv_scens > 0 THEN 1
          ELSE 0 ).


        DATA lv_message TYPE string.

        lv_message =
          |Admin Center import: { lv_tms } target mappings created.|.


        LOOP AT lt_warnings INTO DATA(lv_warn).

          lv_message =
            |{ lv_message }\n{ lv_warn }|.

        ENDLOOP.


        INSERT INTO zzdrj_import_log VALUES @(
          VALUE #(
            import_uuid       = lv_uuid
            import_ts         = lv_ts
            imported_by       = lv_imported_by
            file_name         = ls_param-file_name
            rows_in_file      = lv_rows
            caps_created      = lv_caps
            scenarios_created = lv_scens
            warnings_count    = lines( lt_warnings )
            status            = lv_status
            message           = lv_message ) ).


      CATCH cx_root INTO DATA(lx).

        INSERT INTO zzdrj_import_log VALUES @(
          VALUE #(
            import_uuid       = lv_uuid
            import_ts         = lv_ts
            imported_by       = lv_imported_by
            file_name         = ls_param-file_name
            rows_in_file      = 0
            caps_created      = 0
            scenarios_created = 0
            warnings_count    = 0
            status            = 'ERROR'
            message           = lx->get_text( ) ) ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
