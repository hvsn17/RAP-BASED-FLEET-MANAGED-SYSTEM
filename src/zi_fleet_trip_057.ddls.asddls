@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VIEW ENTITY'
@Metadata.ignorePropagatedAnnotations: true
define  view entity ZI_FLEET_TRIP_057
  as select from zflt_trip_057
  association to parent ZI_FLT_VEHICLE_057 as _Vehicle
    on $projection.VehicleUUID = _Vehicle.VehicleUUID
{
  key tripuuid      as TripUUID,

      vehicleuuid   as VehicleUUID,
      source        as Source,
      destination   as Destination,
      distance      as Distance,
      startdate     as StartDate,
      enddate       as EndDate,
      status        as Status,
      createdat     as CreatedAt,
      lastchangedat as LastChangedAt,
      
      _Vehicle
}
