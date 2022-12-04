## Potential data

https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/datasets/wardlevelmidyearpopulationestimatesexperimental

## To investigate

Area Create (0.8ms)  INSERT INTO "areas" ("gss_code", "name", "area_type_id", "valid_from", "valid_until", "active", "created_at", "updated_at") VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING "id"  [["gss_code", "E05008322"], ["name", "Bryher"], ["area_type_id", 7], ["valid_from", "2004-12-02 00:00:00"], ["valid_until", nil], ["active", true], ["created_at", "2022-10-29 13:41:45.338381"], ["updated_at", "2022-10-29 13:41:45.338381"]]
TRANSACTION (10.3ms)  COMMIT
/home/andrew/Personal/data4democracy/app/lib/mapit/mapit_api.rb:53:in `get_data': HTTP code 404 (Mapit::MapitApi::MapitApiError)
