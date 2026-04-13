@EndUserText.label: 'Trip Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_FLEET_TRIP_057
  as projection on ZI_FLEET_TRIP_057
{
    key TripUUID,
    VehicleUUID,
    Source,
    Destination,
    Distance,
    StartDate,
    EndDate,
    Status,
    CreatedAt,
    LastChangedAt,
    
    /* Associations */
    _Vehicle : redirected to parent ZC_FLT_VEHICLE_057
}
