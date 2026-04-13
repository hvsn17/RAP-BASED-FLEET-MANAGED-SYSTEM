CLASS lhc_Vehicle DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.
    TYPES: tt_vehicle_buffer TYPE TABLE OF zflt_vehicle_057,
           tt_trip_buffer    TYPE TABLE OF zflt_trip_057.

    CLASS-DATA:
      gt_veh_buffer   TYPE tt_vehicle_buffer,
      gt_veh_deleted  TYPE TABLE OF zflt_vehicle_057,
      gt_trip_buffer  TYPE tt_trip_buffer,
      gt_trip_deleted TYPE TABLE OF zflt_trip_057.

  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Vehicle RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Vehicle RESULT result.
    METHODS create FOR MODIFY IMPORTING entities FOR CREATE Vehicle.
    METHODS update FOR MODIFY IMPORTING entities FOR UPDATE Vehicle.
    METHODS delete FOR MODIFY IMPORTING keys FOR DELETE Vehicle.
    METHODS read FOR READ IMPORTING keys FOR READ Vehicle RESULT result.
    METHODS lock FOR LOCK IMPORTING keys FOR LOCK Vehicle.
    METHODS rba_Trips FOR READ IMPORTING keys_rba FOR READ Vehicle\_Trips FULL result_requested RESULT result LINK association_links.
    METHODS cba_Trips FOR MODIFY IMPORTING entities_cba FOR CREATE Vehicle\_Trips.
ENDCLASS.

CLASS lhc_Vehicle IMPLEMENTATION.

  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys ( %tky = key-%tky
                                        %update = if_abap_behv=>auth-allowed
                                        %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD create.
    GET TIME STAMP FIELD DATA(lv_ts).

    LOOP AT entities INTO DATA(ls_entity).
      DATA(lv_uuid) = ls_entity-VehicleUUID.
      IF lv_uuid IS INITIAL.
        lv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      ENDIF.

      IF line_exists( gt_veh_buffer[ vehicleuuid = lv_uuid ] ).
        CONTINUE.
      ENDIF.

      DATA(ls_new_veh) = CORRESPONDING zflt_vehicle_057( ls_entity MAPPING FROM ENTITY ).
      ls_new_veh-vehicleuuid   = lv_uuid.
      ls_new_veh-createdat     = lv_ts.
      ls_new_veh-lastchangedat = lv_ts.
      ls_new_veh-status        = 'C'. " Completed for Green Sign

      INSERT ls_new_veh INTO TABLE gt_veh_buffer.

      APPEND VALUE #( %cid        = ls_entity-%cid
                      VehicleUUID = lv_uuid ) TO mapped-vehicle.
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
    GET TIME STAMP FIELD DATA(lv_ts).

    LOOP AT entities INTO DATA(ls_entity).
      READ TABLE gt_veh_buffer WITH KEY vehicleuuid = ls_entity-VehicleUUID ASSIGNING FIELD-SYMBOL(<fs_veh>).
      IF sy-subrc <> 0.
        SELECT SINGLE * FROM zflt_vehicle_057 WHERE vehicleuuid = @ls_entity-VehicleUUID INTO @DATA(ls_db).
        IF sy-subrc = 0.
          INSERT ls_db INTO TABLE gt_veh_buffer ASSIGNING <fs_veh>.
        ENDIF.
      ENDIF.

      IF <fs_veh> IS ASSIGNED.
        <fs_veh> = CORRESPONDING #( BASE ( <fs_veh> ) ls_entity MAPPING FROM ENTITY ).
        <fs_veh>-lastchangedat = lv_ts.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    LOOP AT keys INTO DATA(ls_key).
      DELETE gt_veh_buffer WHERE vehicleuuid = ls_key-VehicleUUID.
      APPEND VALUE #( vehicleuuid = ls_key-VehicleUUID ) TO gt_veh_deleted.
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(ls_key).
      " 1. Check Buffer
      READ TABLE gt_veh_buffer WITH KEY vehicleuuid = ls_key-VehicleUUID INTO DATA(ls_veh).

      IF sy-subrc <> 0.
        " 2. Check Database
        SELECT SINGLE * FROM zflt_vehicle_057 WHERE vehicleuuid = @ls_key-VehicleUUID INTO @ls_veh.
        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = ls_key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-vehicle.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 3. Map to Result - Check every field name against your ZC view!
      APPEND VALUE #(
        %tky              = ls_key-%tky
        VehicleUUID       = ls_veh-vehicleuuid
        VehicleID         = ls_veh-vehicleid
        registrationno    = ls_veh-registrationno  " Ensure this matches ZC exactly
        vehicletype       = ls_veh-vehicletype
        capacity          = ls_veh-capacity
        status            = ls_veh-status
        StatusCriticality = COND #( WHEN ls_veh-status = 'C' THEN 3
                                    WHEN ls_veh-status = 'N' THEN 1
                                    ELSE 0 )
        createdat         = ls_veh-createdat
        lastchangedat     = ls_veh-lastchangedat
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD rba_Trips.
    LOOP AT keys_rba ASSIGNING FIELD-SYMBOL(<ls_key>).
      LOOP AT gt_trip_buffer INTO DATA(ls_buf) WHERE vehicleuuid = <ls_key>-VehicleUUID.
        APPEND VALUE #( source-%tky = <ls_key>-%tky target-TripUUID = ls_buf-tripuuid ) TO association_links.
      ENDLOOP.

      SELECT tripuuid FROM zflt_trip_057 WHERE vehicleuuid = @<ls_key>-VehicleUUID INTO TABLE @DATA(lt_db).
      LOOP AT lt_db INTO DATA(ls_db).
        IF NOT line_exists( association_links[ target-TripUUID = ls_db-tripuuid ] ).
          APPEND VALUE #( source-%tky = <ls_key>-%tky target-TripUUID = ls_db-tripuuid ) TO association_links.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD cba_Trips.
    GET TIME STAMP FIELD DATA(lv_ts).

    LOOP AT entities_cba INTO DATA(ls_cba).
      LOOP AT ls_cba-%target INTO DATA(ls_target).
        DATA(lv_trip_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(ls_trip) = CORRESPONDING zflt_trip_057( ls_target MAPPING FROM ENTITY ).
        ls_trip-tripuuid      = lv_trip_uuid.
        ls_trip-vehicleuuid   = ls_cba-VehicleUUID.
        ls_trip-createdat     = lv_ts.
        ls_trip-lastchangedat = lv_ts.

        INSERT ls_trip INTO TABLE gt_trip_buffer.
        APPEND VALUE #( %cid = ls_target-%cid TripUUID = lv_trip_uuid ) TO mapped-trip.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_Trip DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS update FOR MODIFY IMPORTING entities FOR UPDATE Trip.
    METHODS delete FOR MODIFY IMPORTING keys FOR DELETE Trip.
    METHODS read   FOR READ   IMPORTING keys FOR READ Trip RESULT result.
    METHODS rba_Vehicle FOR READ IMPORTING keys_rba FOR READ Trip\_Vehicle FULL result_requested RESULT result LINK association_links.
ENDCLASS.

CLASS lhc_Trip IMPLEMENTATION.

  METHOD update.
    GET TIME STAMP FIELD DATA(lv_ts).
    LOOP AT entities INTO DATA(ls_entity).
      READ TABLE lhc_Vehicle=>gt_trip_buffer WITH KEY tripuuid = ls_entity-TripUUID ASSIGNING FIELD-SYMBOL(<fs>).
      IF sy-subrc <> 0.
        SELECT SINGLE * FROM zflt_trip_057 WHERE tripuuid = @ls_entity-TripUUID INTO @DATA(ls_db).
        IF sy-subrc = 0.
          INSERT ls_db INTO TABLE lhc_Vehicle=>gt_trip_buffer ASSIGNING <fs>.
        ENDIF.
      ENDIF.

      IF <fs> IS ASSIGNED.
        <fs> = CORRESPONDING #( BASE ( <fs> ) ls_entity MAPPING FROM ENTITY ).
        <fs>-lastchangedat = lv_ts.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    LOOP AT keys INTO DATA(ls_key).
      DELETE lhc_Vehicle=>gt_trip_buffer WHERE tripuuid = ls_key-TripUUID.
      APPEND VALUE #( tripuuid = ls_key-TripUUID ) TO lhc_Vehicle=>gt_trip_deleted.
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lhc_Vehicle=>gt_trip_buffer WITH KEY tripuuid = ls_key-TripUUID INTO DATA(ls_trip).
      IF sy-subrc <> 0.
        SELECT SINGLE * FROM zflt_trip_057 WHERE tripuuid = @ls_key-TripUUID INTO @ls_trip.
        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = ls_key-%tky %fail-cause = if_abap_behv=>cause-not_found ) TO failed-trip.
          CONTINUE.
        ENDIF.
      ENDIF.

      APPEND VALUE #(
        %tky          = ls_key-%tky
        TripUUID      = ls_trip-tripuuid
        VehicleUUID   = ls_trip-vehicleuuid
        Source        = ls_trip-source
        Destination   = ls_trip-destination
        Distance      = ls_trip-distance
        StartDate     = ls_trip-startdate
        EndDate       = ls_trip-enddate
        Status        = ls_trip-status
        CreatedAt     = ls_trip-createdat
        LastChangedAt = ls_trip-lastchangedat
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Vehicle.
    LOOP AT keys_rba INTO DATA(ls_key).
      SELECT SINGLE vehicleuuid FROM zflt_trip_057 WHERE tripuuid = @ls_key-TripUUID INTO @DATA(lv_parent).
      IF sy-subrc = 0.
        APPEND VALUE #( source-%tky = ls_key-%tky target-VehicleUUID = lv_parent ) TO association_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZI_FLT_VEHICLE_057 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save REDEFINITION.
    METHODS cleanup REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_FLT_VEHICLE_057 IMPLEMENTATION.
  METHOD finalize. ENDMETHOD.
  METHOD check_before_save. ENDMETHOD.

  METHOD save.
    " 1. Batch Delete
    IF lhc_Vehicle=>gt_veh_deleted IS NOT INITIAL.
      DELETE zflt_vehicle_057 FROM TABLE @lhc_Vehicle=>gt_veh_deleted.
    ENDIF.
    IF lhc_Vehicle=>gt_trip_deleted IS NOT INITIAL.
      DELETE zflt_trip_057 FROM TABLE @lhc_Vehicle=>gt_trip_deleted.
    ENDIF.

    " 2. Batch Modify (Handles Create and Update)
    IF lhc_Vehicle=>gt_veh_buffer IS NOT INITIAL.
      MODIFY zflt_vehicle_057 FROM TABLE @lhc_Vehicle=>gt_veh_buffer.
    ENDIF.
    IF lhc_Vehicle=>gt_trip_buffer IS NOT INITIAL.
      MODIFY zflt_trip_057 FROM TABLE @lhc_Vehicle=>gt_trip_buffer.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup.
    CLEAR: lhc_Vehicle=>gt_veh_buffer, lhc_Vehicle=>gt_veh_deleted,
           lhc_Vehicle=>gt_trip_buffer, lhc_Vehicle=>gt_trip_deleted.
  ENDMETHOD.

  METHOD cleanup_finalize. ENDMETHOD.
ENDCLASS.
