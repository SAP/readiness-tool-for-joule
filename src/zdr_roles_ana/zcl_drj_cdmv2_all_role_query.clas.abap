CLASS zcl_drj_cdmv2_all_role_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_drj_cdmv2_all_role_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    " Use the custom entity itself as the result structure.
    " This guarantees that the ABAP result matches the SADL model.
    DATA:
      lt_result       TYPE STANDARD TABLE OF zr_drj_allcdmv2roles
                      WITH EMPTY KEY,

      lt_paged_result TYPE STANDARD TABLE OF zr_drj_allcdmv2roles
                      WITH EMPTY KEY,

      lt_cdm_roles    TYPE zcl_drj_cdm_analysis_util=>tt_role_id,

      lv_commit       TYPE /ui2/content_hash.

    "--------------------------------------------------------------
    " Read all roles exposed through CDM V2
    "--------------------------------------------------------------
    TRY.

        zcl_drj_cdm_analysis_util=>get_cdm_v2_roles(
          IMPORTING
            et_roles  = lt_cdm_roles
            ev_commit = lv_commit
        ).

      CATCH /ui2/cx_ra_repo_exception INTO DATA(lx_repository).

        " Keep the result empty, but do not return here.
        "
        " The common response handling below must still consume:
        " - filter
        " - sorting
        " - paging
        " - requested total count
        CLEAR:
          lt_cdm_roles,
          lv_commit.

    ENDTRY.

    "--------------------------------------------------------------
    " Map utility result to custom entity
    "--------------------------------------------------------------
    lt_result = VALUE #(
      FOR lv_role IN lt_cdm_roles
      (
        rolename = lv_role
      )
    ).

    "--------------------------------------------------------------
    " Filter handling
    "--------------------------------------------------------------
    TRY.

        DATA(lt_filter_ranges) =
          io_request->get_filter( )->get_as_ranges( ).

        READ TABLE lt_filter_ranges
          WITH KEY name = 'ROLENAME'
          INTO DATA(ls_role_filter).

        IF sy-subrc = 0
           AND ls_role_filter-range IS NOT INITIAL.

          DELETE lt_result
            WHERE rolename NOT IN ls_role_filter-range.

        ENDIF.

      CATCH cx_rap_query_filter_no_range.

        " The supplied filter cannot be converted into ranges.
        " No filter is applied in this case.

    ENDTRY.

    "--------------------------------------------------------------
    " Sort handling
    "--------------------------------------------------------------
    DATA(lt_sort_elements) =
      io_request->get_sort_elements( ).

    IF lt_sort_elements IS INITIAL.

      SORT lt_result BY rolename ASCENDING.

    ELSE.

      READ TABLE lt_sort_elements
        INDEX 1
        INTO DATA(ls_sort_element).

      IF sy-subrc = 0.

        CASE to_upper( ls_sort_element-element_name ).

          WHEN 'ROLENAME'.

            IF ls_sort_element-descending = abap_true.

              SORT lt_result BY rolename DESCENDING.

            ELSE.

              SORT lt_result BY rolename ASCENDING.

            ENDIF.

        ENDCASE.

      ENDIF.

    ENDIF.

    "--------------------------------------------------------------
    " Total count must be set before paging
    "--------------------------------------------------------------
    IF io_request->is_total_numb_of_rec_requested( ).

      io_response->set_total_number_of_records(
        lines( lt_result )
      ).

    ENDIF.

    "--------------------------------------------------------------
    " Paging and response data
    "--------------------------------------------------------------
    IF io_request->is_data_requested( ).

      DATA(lo_paging) =
        io_request->get_paging( ).

      DATA(lv_offset) =
        CONV i( lo_paging->get_offset( ) ).

      DATA(lv_page_size) =
        CONV i( lo_paging->get_page_size( ) ).

      DATA(lv_start_index) = lv_offset + 1.
      DATA(lv_end_index)   = lines( lt_result ).

      " A negative page size means that no maximum page size
      " was requested.
      IF lv_page_size >= 0.

        lv_end_index = lv_offset + lv_page_size.

      ENDIF.

      IF lv_end_index > lines( lt_result ).

        lv_end_index = lines( lt_result ).

      ENDIF.

      IF lv_start_index > 0
         AND lv_start_index <= lines( lt_result )
         AND lv_start_index <= lv_end_index.

        LOOP AT lt_result
          INTO DATA(ls_result)
          FROM lv_start_index
          TO lv_end_index.

          APPEND ls_result TO lt_paged_result.

        ENDLOOP.

      ENDIF.

      io_response->set_data( lt_paged_result ).

    ENDIF.

  ENDMETHOD.

ENDCLASS.
