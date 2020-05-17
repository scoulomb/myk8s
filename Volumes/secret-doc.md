# Reference

Doc referenced here:
https://github.com/dgkanatsios/CKAD-exercises/blob/master/d.configuration.md#secrets

# Secret concept doc 

https://kubernetes.io/docs/concepts/configuration/secret/

## Overview

https://kubernetes.io/docs/concepts/configuration/secret/#overview-of-secrets
> A secret can be used with a Pod in two ways:
> As files in a volume mounted on one or more of its containers.
Miss consumption as environment variable in the doc
clearly stated later: https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets

And see this 
https://github.com/scoulomb/myk8s/blob/master/Volumes/fluentd-tutorial.md#explanations-and-wrap-up
https://github.com/scoulomb/myk8s/blob/master/Volumes/volume4question.md#4-ConfigMap-consumption

Pod is important to not includes controller case, other case are particular case, clear 

> By the kubelet when pulling images for the Pod.

otherwise aligned

## Create secret manually 

https://kubernetes.io/docs/concepts/configuration/secret/#creating-a-secret-manually

As done in [Security section](../Security/1-secret-creation-consumption.md#Create-secret).

Generator assume as configmap genraator work only with files, not folder
(see ckad exo, file d)

## Usage

### 1 - Consumption as volume

#### Standard

As seen in this [volume section](fluentd-tutorial.md).
Or in [security section](../Security/1-secret-creation-consumption.md#Then-create-a-pod-which-consumes-the-secret-as-volume).
)
And documented here: https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets

#### API credentials

https://kubernetes.io/docs/concepts/configuration/secret/#service-accounts-automatically-create-and-attach-secrets-with-api-credentials
> Kubernetes automatically creates secrets which contain credentials for accessing the API and automatically modifies your Pods to use this type of secret.

Indeed we see in [security section](../Security/2-service-account.md)
with default and custom sa 

And done here: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#use-the-default-service-account-to-access-the-api-server
and https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#use-multiple-service-accounts

### 2 - consumption as environment variable

https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-environment-variables

### 3 - Image pull secret 

https://kubernetes.io/docs/concepts/configuration/secret/#using-imagepullsecrets

## Injection 

### Atachment to service account 

Similar to what is done with [API credentials](#API-credentials) 
https://kubernetes.io/docs/concepts/configuration/secret/#automatic-mounting-of-manually-created-secrets

Thu service account exactly what when creates robotic user and login directly with it

### Pod preset

https://kubernetes.io/docs/concepts/configuration/secret/#automatic-mounting-of-manually-created-secrets

## Note on mode

https://stackoverflow.com/questions/18415904/what-does-mode-t-0644-mean
first 0 means we are in octal, this what we are used to do
Remove it in conversion
https://www.rapidtables.com/convert/number/octal-to-decimal.html
==> OK

## Sync 

Subpath same as CM
https://kubernetes.io/docs/concepts/configuration/secret/#mounted-secrets-are-updated-automatically

## Synthax

https://kubernetes.io/docs/concepts/configuration/secret/#creating-a-secret-manually

`|-` it is a json with a key and big string, json2yanl, json lint

See https://gist.github.com/scoulomb/f798c97d4c9d048451a8e0f066f27be2


All OK except PR DONE:
https://github.com/kubernetes/website/pull/21028

# Secret Tasks doc

https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/

Display the content of `SECRET_USERNAME` environment variable

````
kubectl exec -it env-single-secret -- /bin/sh -c 'echo $SECRET_USERNAME'
````

The output is 

````
backend-admin
````

Note the '' and not "" as otherwise interpreted in current shell
I could have done env | grep


````shell script
➤ kubectl exec -it envvars-multiple-secrets -- /bin/sh -c 'env | grep _USERNAME'
DB_USERNAME=db-admin
BACKEND_USERNAME=backend-admin

➤ kubectl exec -it envfrom-secret -- /bin/sh -c 'echo "username: $username\npassword: $password"'
username: my-app
password: 39528$vdg7Jb
````

All OK
PR to improve output and 2 spaces in more
DONE: https://github.com/kubernetes/website/pull/21027 