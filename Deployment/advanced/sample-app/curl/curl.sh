set -o xtrace
sleep 5
curl --request GET --header 'Content-Type: application/json' http://server:8080/api/v1/time
sleep 5
curl --request GET --header 'Content-Type: application/json' http://server:8080/api/v1/time
sleep 5
curl --request GET --header 'Content-Type: application/json' http://server:8080/api/v1/time

