# Volumes without external provider (Azure, AWS...)

- Use `EmptyDir`:https://kubernetes.io/docs/concepts/storage/volumes/#emptydir if not persitency neededed.
- If to read a git repo use `GitRepo`: https://kubernetes.io/docs/concepts/storage/volumes/#gitrepo or Empty Dir with init container which will read repo content
- If persitency on a node use
	- `HostPath`https://kubernetes.io/docs/concepts/storage/volumes/#hostpath (work on single node environment and not production friendly)
	- `Local` Use https://kubernetes.io/docs/concepts/storage/volumes/#local and node affinity (best++)
	
- Or `NFS` and deploy NFS server: https://kubernetes.io/docs/concepts/storage/volumes/#nfs (could use [QNAP NAS](https://github.com/scoulomb/misc-notes/blob/master/NAS-setup/README.md))


Note that `Local` volume unlike `HostPath` requires a pvc,
See [volume questions](./volume4question.md#1-emptydir-and-pvc).

<!-- ok clear -->
<!-- when using docker in local close to hostpath/local -->