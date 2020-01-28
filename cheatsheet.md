# Cheatsheet

# Execution within a container

```
for name in try1-9b4568b5c-9pcst try1-9b4568b5c-h9rml
do 
k exec $name -c simpleapp touch /tmp/healthy
done
```
```
k exec -it try1-9b4568b5c-kswfc  -c simpleapp -- /bin/bash
```
