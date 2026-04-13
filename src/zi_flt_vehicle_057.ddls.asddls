@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ROOT'
define root view entity ZI_FLT_VEHICLE_057 
  as select from zflt_vehicle_057
  composition [0..*] of ZI_FLEET_TRIP_057 as _Trips
{
  key vehicleuuid   as VehicleUUID,
      vehicleid     as VehicleID,
      registrationno as RegistrationNo, -- Check casing!
      vehicletype   as VehicleType,
      capacity      as Capacity,
      status        as Status,
      
      /* Add Criticality for the Green Sign */
      case status
        when 'C' then 3
        when 'N' then 1
        else 0
      end           as StatusCriticality,

      createdat     as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      lastchangedat as LastChangedAt,

      _Trips
}
