# HereDoc

## Heredoc basic


https://fr.wikipedia.org/wiki/Here_document

````
cat << FIN 
Current user is $USER
FIN

cat << FIN > toto.txt
Current user is $USER
FIN
````

## Heredoc apply to kubernetes

Alternative to 

````
echo '
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: $(echo -n "s33msi4" | base64 -w0)
  username: $(echo -n "jane" | base64 -w0)
' > secret.yaml
k apply -f secret.yaml
````

Done in ckad/e
https://kubernetes.io/docs/concepts/configuration/secret/#use-case-pods-with-prod--test-credentials

````
cat <<EOF 
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: $(echo -n "s33msi4" | base64 -w0)
  username: $(echo -n "jane" | base64 -w0)
EOF

cat <<EOF > pod.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: $(echo -n "s33msi4" | base64 -w0)
  username: $(echo -n "jane" | base64 -w0)
EOF

k apply -f pod.yaml

````
## Combined with a pipe and - (stdout)

https://kubernetes.io/docs/reference/kubectl/cheatsheet/

````
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  password: $(echo -n "s33msi4" | base64 -w0)
  username: $(echo -n "jane" | base64 -w0)
EOF
````

## multifile

Here we have a list: https://kubernetes.io/docs/concepts/configuration/secret/#use-cases
in kind but possible to have manifest seprated by `----`

cf: https://github.com/dgkanatsios/CKAD-exercises/blob/master/f.services.md

````
k run nginx --image=nginx --restart=Never --port=80 --expose
````
