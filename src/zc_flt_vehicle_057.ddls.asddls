@EndUserText.label: 'Vehicle Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZC_FLT_VEHICLE_057
  provider contract transactional_query
  as projection on ZI_FLT_VEHICLE_057
{
    key VehicleUUID,
    VehicleID,
    RegistrationNo,
    VehicleType,
    Capacity,
    Status,
    
    /* 1. Just reference the field from ZI - No CASE expression here */
    StatusCriticality,

    CreatedAt,
    LastChangedAt,
    
    /* Associations */
    _Trips : redirected to composition child ZC_FLEET_TRIP_057
}
