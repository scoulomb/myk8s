# README

## Install compose

```
sudo apt-get install docker-compose
```


## Version

- version 1: initial version
- version 2: same as verson but printing v2 in json
- version 3: same as v2 but return a 500 after 12 seconds

## Run server

Specify good compose file to build and run the correct version


```
sudo docker-compose -f docker-compose.yaml up --build # -f optional here
sudo docker-compose -f docker-composev2.yaml up --build
sudo docker-compose -f docker-composev3.yaml up --build
```

## Check images are present in node

```
sylvain@sylvain-hp:~/sample$ sudo docker images | grep server
server                                    v3                  0269f5937992        10 minutes ago      231MB
server                                    v1                  b6ecdc3830bc        19 minutes ago      231MB
server                                    v2                  cb8ea3211722        26 minutes ago      231MB
server                                    latest              1b7f65239c2d        32 minutes ago      231MB
k8s.gcr.io/kube-apiserver                 v1.18.2             6ed75ad404bd        5 weeks ago         173MB
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
