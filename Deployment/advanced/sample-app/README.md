# README

## Install compose

```
sudo apt-get install docker-compose
```


## Version

- version 1: initial version
- version 2: same as version but printing v2 in json
- version 3: same as v2 but return a 500 after 12 seconds
- version 4: same as v2 but return v4 in json and a dummy field
## Run server

Specify good compose file to build and run the correct version
(copy the sample file in a VM accessible from your machine)

```
sudo docker-compose -f docker-compose.yaml up --build # -f optional here
sudo docker-compose -f docker-composev2.yaml up --build
sudo docker-compose -f docker-composev3.yaml up --build
sudo docker-compose -f docker-composev4.yaml up --build
```

## Check images are present in node

```
➤ sudo docker images | grep server                                                                                                                                            vagrant@archlinux
server                                                                           v4                  0637845dec4b        2 minutes ago       263MB
server                                                                           v3                  bc97784e642f        5 minutes ago       263MB
server                                                                           v2                  36c4bb8b39dc        5 minutes ago       263MB
server                                                                           v1                  47e8cf58f529        7 minutes ago       263MB
[...]
```

## Alternative run

To run only the server do:

````
sudo docker-compose up --build server 
````

Add -f for version 2 and 3.

Note the port forwarding.
If use `docker run` add `-p` option.

````
cd server # v2,v3
sudo docker build . -f pod.Dockerfile -t server 
sudo docker run -p 8080:8080 server
```` 

If using a VM when performing the curl, check also port forwarding rule at VM level

## Original repo

https://github.com/scoulomb/zalando_connexion_sample (lb, see flask flavour)
