*&---------------------------------------------------------------------*
*& Class:        ZCL_ZEWM004_TRANSFER
*& Application:  ZEWM004 - Internal Transfer (IM-EWM)
*& Purpose:      Screen1 (Create HU) backend logic. Methods below are
*&               called directly by name from the generic V2 dispatcher
*&               (frontend sends { fname: "ZCL_ZEWM004_TRANSFER", mname: <METHOD> },
*&               dispatcher does CREATE OBJECT + CALL METHOD lo_obj->(mname)
*&               with REQPARAM in / RESTYPE, RESMSG, RESDATA out) - so the
*&               public method names/parameters below must match what the
*&               frontend calls (check_material/check_sloc/check_batch/
*&               check_qty/check_packmat/create_hu).
*&
*& NOTE: CDS view/field names normalized from the supplied spec and must
*&       be verified against the actual system:
*&         - CHECK_BATCH additionally filters on Batch itself (the
*&           spec only mentioned Plant+Material, but a batch check
*&           that ignores the batch value would be meaningless)
*&         - CALL_CREATE_HU_API reuses the ZZT_REST_SYSID / 'SELF'
*&           loopback pattern from ZCL_ZEWM005_TRANSFER's CALL_MOVE_HU_API
*&---------------------------------------------------------------------*
CLASS zcl_zewm004_transfer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ── V2 调度器直接调用的方法（必须 PUBLIC，接受 REQPARAM）──
    METHODS check_material
      IMPORTING reqparam TYPE string
      EXPORTING restype  TYPE string
                resmsg   TYPE string
                resdata  TYPE string.

    METHODS check_sloc
      IMPORTING reqparam TYPE string
      EXPORTING restype  TYPE string
                resmsg   TYPE string
                resdata  TYPE string.

    METHODS check_batch
      IMPORTING reqparam TYPE string
      EXPORTING restype  TYPE string
                resmsg   TYPE string
                resdata  TYPE string.

    METHODS check_qty
      IMPORTING reqparam TYPE string
      EXPORTING restype  TYPE string
                resmsg   TYPE string
                resdata  TYPE string.

    METHODS check_packmat
      IMPORTING reqparam TYPE string
      EXPORTING restype  TYPE string
                resmsg   TYPE string
                resdata  TYPE string.

    METHODS create_hu
      IMPORTING reqparam TYPE string
      EXPORTING restype  TYPE string
                resmsg   TYPE string
                resdata  TYPE string.

    " ── 调标准 API_HANDLINGUNIT_0001 (HandlingUnit) 创建 HU ──
    METHODS call_create_hu_api
      IMPORTING
        iv_material TYPE matnr
        iv_sloc     TYPE lgort_d
        iv_batch    TYPE charg_d
        iv_qty      TYPE string
        iv_packmat  TYPE matnr
        iv_unit     TYPE meins
      EXPORTING
        ev_success  TYPE abap_bool
        ev_hu       TYPE string
        ev_message  TYPE string.

  PRIVATE SECTION.
    CONSTANTS co_plant TYPE werks_d VALUE 'BORJ'.

    " ── Helper: 从 reqparam JSON 中提取指定 key 的字符串值 ──
    METHODS get_json_value
      IMPORTING iv_json       TYPE string
                iv_key        TYPE string
      RETURNING VALUE(rv_val) TYPE string.

    " ── Helper: 校验方法（供 CHECK_XXX 和 CREATE_HU 复用）──
    METHODS validate_material
      IMPORTING iv_material TYPE matnr
      EXPORTING ev_restype  TYPE string
                ev_resmsg   TYPE string.

    METHODS validate_sloc
      IMPORTING iv_sloc     TYPE lgort_d
      EXPORTING ev_restype  TYPE string
                ev_resmsg   TYPE string.

    METHODS validate_batch
      IMPORTING iv_material TYPE matnr
                iv_batch    TYPE charg_d
      EXPORTING ev_restype  TYPE string
                ev_resmsg   TYPE string.

    METHODS validate_qty
      IMPORTING iv_material TYPE matnr
                iv_sloc     TYPE lgort_d
                iv_batch    TYPE charg_d
                iv_qty      TYPE string
      EXPORTING ev_restype  TYPE string
                ev_resmsg   TYPE string.

    METHODS validate_packmat
      IMPORTING iv_packmat  TYPE matnr
      EXPORTING ev_restype  TYPE string
                ev_resmsg   TYPE string.

    METHODS get_base_unit
      IMPORTING iv_material    TYPE matnr
      RETURNING VALUE(rv_unit) TYPE meins.

    METHODS get_recommended_bin
      IMPORTING iv_material   TYPE matnr
      RETURNING VALUE(rv_bin) TYPE string.

ENDCLASS.


CLASS zcl_zewm004_transfer IMPLEMENTATION.

  METHOD get_json_value.
* ---------------------------------------------------------------
* 内部方法：简单 JSON 字符串值提取
* 匹配 "key":"value" 或 "key":[...]
* ---------------------------------------------------------------
    DATA lv_key_clean TYPE string.
    lv_key_clean = iv_key.

    " 先匹配字符串值: "key":"value"
    FIND FIRST OCCURRENCE OF REGEX
      |"{ lv_key_clean }"\\s*:\\s*"([^"]*)"|
      IN iv_json
      SUBMATCHES rv_val.

    " 字符串未匹配，尝试数组值: "key":[...]
    IF rv_val IS INITIAL.
      FIND FIRST OCCURRENCE OF REGEX
        |"{ lv_key_clean }"\\s*:\\s*(\\[[^\\]]*\\])|
        IN iv_json
        SUBMATCHES rv_val.
    ENDIF.

    CONDENSE rv_val.
  ENDMETHOD.


  " Mandatory check, then existence check against I_Product-Product
  METHOD validate_material.
    IF iv_material IS INITIAL.
      ev_restype = 'E'.
      ev_resmsg  = |Field 'Material' is mandatory.|.
      RETURN.
    ENDIF.

    SELECT SINGLE product
      FROM i_product WITH PRIVILEGED ACCESS AS a
      WHERE product = @iv_material
      INTO @DATA(lv_product).

    IF sy-subrc <> 0.
      ev_restype = 'E'.
      ev_resmsg  = |Material { iv_material } doesn't exist in warehouse.|.
      RETURN.
    ENDIF.

    ev_restype = 'S'.
  ENDMETHOD.


  " Mandatory check, then existence check against I_Location (Plant = BORJ)
  METHOD validate_sloc.
    IF iv_sloc IS INITIAL.
      ev_restype = 'E'.
      ev_resmsg  = |Field 'Src Loc' is mandatory.|.
      RETURN.
    ENDIF.

    SELECT SINGLE location
      FROM i_location WITH PRIVILEGED ACCESS AS a
      WHERE plant    = @co_plant
        AND location = @iv_sloc
      INTO @DATA(lv_location).

    IF sy-subrc <> 0.
      ev_restype = 'E'.
      ev_resmsg  = |Location { iv_sloc } doesn't exist in plant { co_plant }.|.
      RETURN.
    ENDIF.

    ev_restype = 'S'.
  ENDMETHOD.


  " Mandatory check, then existence check against I_Batch (Plant = BORJ, Material, Batch)
  METHOD validate_batch.
    IF iv_batch IS INITIAL.
      ev_restype = 'E'.
      ev_resmsg  = |Field 'Batch' is mandatory.|.
      RETURN.
    ENDIF.

    SELECT SINGLE batch
      FROM i_batch WITH PRIVILEGED ACCESS AS a
      WHERE plant    = @co_plant
        AND material = @iv_material
        AND batch    = @iv_batch
      INTO @DATA(lv_batch).

    IF sy-subrc <> 0.
      ev_restype = 'E'.
      ev_resmsg  = |Batch { iv_batch } doesn't exist for material { iv_material }.|.
      RETURN.
    ENDIF.

    ev_restype = 'S'.
  ENDMETHOD.


  " Mandatory check, then available quantity check against I_MaterialStock_2
  METHOD validate_qty.
    DATA lv_stock_qty TYPE p LENGTH 13 DECIMALS 3.
    DATA lv_input_qty TYPE p LENGTH 13 DECIMALS 3.

    IF iv_qty IS INITIAL.
      ev_restype = 'E'.
      ev_resmsg  = |Field 'Qty' is mandatory.|.
      RETURN.
    ENDIF.

    lv_input_qty = iv_qty.

    SELECT SINGLE matlwrhsstkqtyinmatlbaseunit
      FROM i_materialstock_2 WITH PRIVILEGED ACCESS AS a
      WHERE plant           = @co_plant
        AND storagelocation = @iv_sloc
        AND batch           = @iv_batch
        AND material        = @iv_material
      INTO @lv_stock_qty.

    IF sy-subrc <> 0 OR lv_stock_qty < lv_input_qty.
      ev_restype = 'E'.
      ev_resmsg  = |No available quantity.|.
      RETURN.
    ENDIF.

    ev_restype = 'S'.
  ENDMETHOD.


  " Mandatory check, then I_Product-ProductType must be 'VEKP'
  METHOD validate_packmat.
    IF iv_packmat IS INITIAL.
      ev_restype = 'E'.
      ev_resmsg  = |Field 'Pack. Mat' is mandatory.|.
      RETURN.
    ENDIF.

    SELECT SINGLE producttype
      FROM i_product WITH PRIVILEGED ACCESS AS a
      WHERE product = @iv_packmat
      INTO @DATA(lv_product_type).

    IF sy-subrc <> 0 OR lv_product_type <> 'VEKP'.
      ev_restype = 'E'.
      ev_resmsg  = |Packaging material { iv_packmat } is invalid.|.
      RETURN.
    ENDIF.

    ev_restype = 'S'.
  ENDMETHOD.


  METHOD get_base_unit.
    SELECT SINGLE materialbaseunit
      FROM i_materialstock_2 WITH PRIVILEGED ACCESS AS a
      WHERE material = @iv_material
      INTO @rv_unit.
  ENDMETHOD.


  " I_EWM_FixedBinAssignment-EWMStorageBin based on Product = input material
  METHOD get_recommended_bin.
    SELECT SINGLE ewmstoragebin
      FROM i_ewm_fixedbinassignment WITH PRIVILEGED ACCESS AS a
      WHERE product = @iv_material
      INTO @rv_bin.
  ENDMETHOD.


  METHOD check_material.
* ── CHECK_MATERIAL ──────────────────────────────────────────────────
    DATA(lv_material) = get_json_value( iv_json = reqparam iv_key = 'material' ).

    validate_material(
      EXPORTING iv_material = lv_material
      IMPORTING ev_restype  = restype
                ev_resmsg   = resmsg ).
  ENDMETHOD.


  METHOD check_sloc.
* ── CHECK_SLOC ──────────────────────────────────────────────────────
    DATA(lv_sloc) = get_json_value( iv_json = reqparam iv_key = 'srcLoc' ).

    validate_sloc(
      EXPORTING iv_sloc    = lv_sloc
      IMPORTING ev_restype = restype
                ev_resmsg  = resmsg ).
  ENDMETHOD.


  METHOD check_batch.
* ── CHECK_BATCH ─────────────────────────────────────────────────────
    DATA(lv_material) = get_json_value( iv_json = reqparam iv_key = 'material' ).
    DATA(lv_batch)    = get_json_value( iv_json = reqparam iv_key = 'batch' ).

    validate_batch(
      EXPORTING iv_material = lv_material
                iv_batch    = lv_batch
      IMPORTING ev_restype  = restype
                ev_resmsg   = resmsg ).
  ENDMETHOD.


  METHOD check_qty.
* ── CHECK_QTY ───────────────────────────────────────────────────────
    DATA(lv_material) = get_json_value( iv_json = reqparam iv_key = 'material' ).
    DATA(lv_sloc)     = get_json_value( iv_json = reqparam iv_key = 'srcLoc' ).
    DATA(lv_batch)    = get_json_value( iv_json = reqparam iv_key = 'batch' ).
    DATA(lv_qty)      = get_json_value( iv_json = reqparam iv_key = 'qty' ).

    validate_qty(
      EXPORTING iv_material = lv_material
                iv_sloc     = lv_sloc
                iv_batch    = lv_batch
                iv_qty      = lv_qty
      IMPORTING ev_restype  = restype
                ev_resmsg   = resmsg ).
  ENDMETHOD.


  METHOD check_packmat.
* ── CHECK_PACKMAT ───────────────────────────────────────────────────
    DATA(lv_packmat) = get_json_value( iv_json = reqparam iv_key = 'packMat' ).

    validate_packmat(
      EXPORTING iv_packmat = lv_packmat
      IMPORTING ev_restype = restype
                ev_resmsg  = resmsg ).
  ENDMETHOD.


  METHOD create_hu.
* ── CREATE_HU ───────────────────────────────────────────────────────
* Re-validates all 5 fields in the Material -> Src Loc -> Batch -> Qty ->
* Pack Mat order, then creates the HU via API_HANDLINGUNIT_0001 and looks
* up the recommended bin for the response payload consumed by Screen2.
    DATA lv_restype TYPE string.
    DATA lv_resmsg  TYPE string.

    DATA(lv_material) = get_json_value( iv_json = reqparam iv_key = 'material' ).
    DATA(lv_sloc)     = get_json_value( iv_json = reqparam iv_key = 'srcLoc' ).
    DATA(lv_batch)    = get_json_value( iv_json = reqparam iv_key = 'batch' ).
    DATA(lv_qty)      = get_json_value( iv_json = reqparam iv_key = 'qty' ).
    DATA(lv_packmat)  = get_json_value( iv_json = reqparam iv_key = 'packMat' ).

    validate_material(
      EXPORTING iv_material = lv_material
      IMPORTING ev_restype  = lv_restype
                ev_resmsg   = lv_resmsg ).
    IF lv_restype = 'E'.
      restype = lv_restype. resmsg = lv_resmsg. RETURN.
    ENDIF.

    validate_sloc(
      EXPORTING iv_sloc    = lv_sloc
      IMPORTING ev_restype = lv_restype
                ev_resmsg  = lv_resmsg ).
    IF lv_restype = 'E'.
      restype = lv_restype. resmsg = lv_resmsg. RETURN.
    ENDIF.

    validate_batch(
      EXPORTING iv_material = lv_material
                iv_batch    = lv_batch
      IMPORTING ev_restype  = lv_restype
                ev_resmsg   = lv_resmsg ).
    IF lv_restype = 'E'.
      restype = lv_restype. resmsg = lv_resmsg. RETURN.
    ENDIF.

    validate_qty(
      EXPORTING iv_material = lv_material
                iv_sloc     = lv_sloc
                iv_batch    = lv_batch
                iv_qty      = lv_qty
      IMPORTING ev_restype  = lv_restype
                ev_resmsg   = lv_resmsg ).
    IF lv_restype = 'E'.
      restype = lv_restype. resmsg = lv_resmsg. RETURN.
    ENDIF.

    validate_packmat(
      EXPORTING iv_packmat = lv_packmat
      IMPORTING ev_restype = lv_restype
                ev_resmsg  = lv_resmsg ).
    IF lv_restype = 'E'.
      restype = lv_restype. resmsg = lv_resmsg. RETURN.
    ENDIF.

    DATA(lv_unit) = get_base_unit( lv_material ).

    DATA lv_success TYPE abap_bool.
    DATA lv_hu      TYPE string.
    DATA lv_message TYPE string.

    call_create_hu_api(
      EXPORTING iv_material = lv_material
                iv_sloc     = lv_sloc
                iv_batch    = lv_batch
                iv_qty      = lv_qty
                iv_packmat  = lv_packmat
                iv_unit     = lv_unit
      IMPORTING ev_success  = lv_success
                ev_hu       = lv_hu
                ev_message  = lv_message ).

    IF lv_success <> abap_true.
      restype = 'E'.
      resmsg  = lv_message.
      RETURN.
    ENDIF.

    DATA(lv_bin) = get_recommended_bin( lv_material ).

    restype = 'S'.
    resmsg  = |HU { lv_hu } created successfully.|.
    resdata = |\{"hu":"{ lv_hu }","recommendedBin":"{ lv_bin }"\}|.
  ENDMETHOD.


  METHOD call_create_hu_api.
* ── 调 S/4HANA 标准 API_HANDLINGUNIT_0001 (HandlingUnit) 创建 HU ──
    DATA: lv_csrf     TYPE string,
          lv_response TYPE string,
          lv_body     TYPE string.

    SELECT SINGLE *
      FROM zzt_rest_sysid
     WHERE zztsysid = 'SELF'
      INTO @DATA(ls_sysid).

    DATA(lv_base_url) =
      |{ ls_sysid-zzurl }/sap/opu/odata4/sap/api_handlingunit/srvd_a2x/sap/handlingunit/0001/|.

    DATA(lv_post_path) =
      |/sap/opu/odata4/sap/api_handlingunit/srvd_a2x/sap/handlingunit/0001/HandlingUnit|.

    TRY.
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
          i_destination = cl_http_destination_provider=>create_by_url( i_url = lv_base_url ) ).

        " Step 1: GET CSRF token
        DATA(lo_req) = lo_client->get_http_request( ).
        lo_req->set_authorization_basic(
          i_username = CONV string( ls_sysid-zzuser )
          i_password = CONV string( ls_sysid-zzpwd ) ).
        lo_req->set_header_field( i_name = 'x-csrf-token' i_value = 'fetch' ).
        lo_req->set_header_field( i_name = 'Accept'       i_value = 'application/json' ).

        DATA(lo_resp) = lo_client->execute( if_web_http_client=>get ).
        lo_resp->get_header_field(
          EXPORTING i_name  = 'x-csrf-token'
          RECEIVING r_value = lv_csrf ).

        IF lv_csrf IS INITIAL.
          lo_client->close( ).
          ev_success = abap_false.
          ev_message = 'Failed to fetch CSRF token.'.
          RETURN.
        ENDIF.

        " Step 2: POST HandlingUnit (with nested _HandlingUnitItem)
        lv_body =
          |\{| &&
          |"HandlingUnitExternalID":"",| &&
          |"Warehouse":"",| &&
          |"PackagingMaterial":"{ iv_packmat }",| &&
          |"_HandlingUnitItem":[| &&
            |\{| &&
            |"HandlingUnitExternalID":"",| &&
            |"HandlingUnitTypeOfContent":"1",| &&
            |"Plant":"{ co_plant }",| &&
            |"StorageLocation":"{ iv_sloc }",| &&
            |"Material":"{ iv_material }",| &&
            |"Batch":"{ iv_batch }",| &&
            |"HandlingUnitQuantity":{ iv_qty },| &&
            |"HandlingUnitQuantityUnit":"{ iv_unit }"| &&
            |\}| &&
          |]| &&
          |\}|.

        DATA(lo_post_req) = lo_client->get_http_request( ).
        lo_post_req->set_uri_path( i_uri_path = lv_post_path ).
        lo_post_req->set_authorization_basic(
          i_username = CONV string( ls_sysid-zzuser )
          i_password = CONV string( ls_sysid-zzpwd ) ).
        lo_post_req->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
        lo_post_req->set_header_field( i_name = 'x-csrf-token' i_value = lv_csrf ).
        lo_post_req->set_text( lv_body ).

        DATA(lo_post_resp) = lo_client->execute( if_web_http_client=>post ).
        DATA(lv_status)    = lo_post_resp->get_status( ).
        lv_response        = lo_post_resp->get_text( ).

        lo_client->close( ).

        IF lv_status-code >= 200 AND lv_status-code < 300.
          ev_success = abap_true.
          ev_hu      = get_json_value( iv_json = lv_response iv_key = 'HandlingUnitExternalID' ).
        ELSE.
          ev_success = abap_false.
          ev_message = lv_response.
        ENDIF.

      CATCH cx_root INTO DATA(lx).
        ev_success = abap_false.
        ev_message = lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
