# Archlinux DEV VM known issue

When reloading last VM version we had following issues when working on development tasks.
(docker, docker-compose, python base image with pipenv as python package manager).

## Issue 1: Running code from pipenv 

[solved]

````shell script
https://unix.stackexchange.com/questions/74520/can-i-redirect-output-to-a-log-file-and-background-a-process-at-the-same-time
pipenv run python run.py --verbose > /tmp/out.txt 2>&1 &
````

We had error

````shell script
Allowed hash algorithms for --hash are sha256, sha384, sha512 
````

For package referenced in pipfile which used private pypy package (artifactory).

<!--  http-lib -->

We believed it was coming from a too recent version of pipenv: https://github.com/pypa/pipenv/pull/4519 (recent issue at time of writing 4Dec2020).
But same issue occurs in Docker (see below), where the version is fixed. 

If that occurs changing VPN region can fix the issue. 
<!-- blr -->

We could use poetry instead of pipenv, but there is low probability it would have fixed the issue shown here.

<!-- to check if issue global or local we can think to use the CI -->


## Issue 2: Running code from Docker image

[workaround]

### Issue

````shell script
docker build . -f service.dockerfile -t api-server
````


We had that issue: https://stackoverflow.com/questions/12338233/shell-init-issue-when-click-tab-whats-wrong-with-getcwd

````shell script
➤ docker build .
error checking context: 'lstat /home/vagrant/dev/my-automation/myproj_automation/dictionary_filter/__init__.py: interrupted system call'.
[11:14][master]⚡? ~/dev/my-automation
➤ shell-init: error retrieving current directory: getcwd: cannot access parent directories: No such file or directory
error: getcwd() failed with errno 2/No such file or directory
[11:14] master]⚡? ~/dev/my-automationking directory. Is your locale set correctly?
````

W can improve it by doing

````shell script
fisher rm acomagu/fish-async-prompt 
logout/login
````

But still issue:

````shell script
error checking context: 'lstat /home/vagrant/dev/my-automation/non_regression/src/test/java/infoblox_api_direct_call/create_myprojview.feature: interrupted system call'.
```` 

This is due to the fact Windows is doing file manipulation in the vagrant sync folder causing the issue.
The sync in the VM enable to run the code in the VM while editing it via Pycharm for instance.

We have met similar issue with pipenv.
`The folder you are executing pip from can no longer be found.` but just cd out, cd in fixed the issue for pipenv unlike Docker.

### Workaround 1: keep using Docker and copy repo out of the vagrant sync folder

````shell script
sudo cp -R ~/dev/my-repo /my-repo
docker build /my-repo -f /my-repo/service.dockerfile -t my-api-server
docker run  my-api-server
````

Note we can have same error as [Running code from pipenv](#running-code-from-pipenv) if not fixed.

We could sync via rsync (https://stackoverflow.com/questions/12460279/how-to-keep-two-folders-automatically-synchronized) rather than doing a copy.
### Workaround 2: Use docker-compose

````shell script
docker-compose up --build
````

When using `docker-compose`, which is using a different docker context as Docker the issue did not occur.
Note compose will build and run.

<!-- 
Note docker compose has command which is docker cmd
See https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-d.md#kubernetes-link
and https://github.com/scoulomb/http-over-socket/blob/main/docker-compose.yaml -->

### Workaround 3: Use podman 

Docker is failing

````shell script
[16:19][master]⚡? ~/dev/my-automation
➤ docker build . -f service.dockerfile -t api-server
ERRO[0001] Tar: Can't stat file /home/vagrant/dev [...]
sudo pacman -S podman
podman build . -f service.dockerfile -t api-server-podman
exit
vagrant ssh
````

Retry with podman is working but we have another issue which is unrelated to sync.


````shell script
cd ~/dev/my-automation
➤ cat yop.dockerfile
FROM scoulomb/docker-doctor:dev

RUN ["/bin/echo", "hello"]⏎

➤ sudo podman build -f yop.Dockerfile -t api-server-podman
STEP 1: FROM scoulomb/docker-doctor:dev
Completed short name "scoulomb/docker-doctor" with unqualified-search registries (origin: /etc/containers/registries.conf)
STEP 2: RUN ["/bin/echo", "hello"]
ERRO[0000] container_linux.go:370: starting container process caused: exec: "/bin/echo": stat /bin/echo: no such file or directory
error running container: error creating container for [/bin/echo hello]: : exit status 1
Error: error building at STEP "RUN /bin/echo hello": error while running runtime: exit status 1


➤ cat yop.dockerfile
FROM scoulomb/docker-doctor:dev

RUN ["echo", "hello"]⏎
➤ sudo podman build -f yop.Dockerfile -t api-server-podman
STEP 1: FROM scoulomb/docker-doctor:dev
Completed short name "scoulomb/docker-doctor" with unqualified-search registries (origin: /etc/containers/registries.conf)
STEP 2: RUN ["echo", "hello"]
ERRO[0000] container_linux.go:370: starting container process caused: exec: "echo": executable file not found in $PATH
error running container: error creating container for [echo hello]: : exit status 1
Error: error building at STEP "RUN echo hello": error while running runtime: exit status 1
````

Note run has also exec and shell form. See https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-d.md


<!-- in  dns.current for all alternatives: [s4-0] Launch API server we have seen all ways to run, until OpenShift -->

Note this issue seems Archlinux VM specific. Here on Ubuntu:

````shell script
➤ ssh sylvain@109.29.148.109
[...]

Your Hardware Enablement Stack (HWE) is supported until April 2025.
Last login: Thu Nov 26 10:38:29 2020 from 192.168.1.1
sylvain@sylvain-hp:~$
sylvain@sylvain-hp:~$
sylvain@sylvain-hp:~$ podman
Error: missing command 'podman COMMAND'
Try 'podman --help' for more information.
sylvain@sylvain-hp:~$ vim yop.Dockerfile
sylvain@sylvain-hp:~$ podman build .
Error: error reading info about "/home/sylvain/home/sylvain/Dockerfile": stat /home/sylvain/home/sylvain/Dockerfile: no such file or directory
sylvain@sylvain-hp:~$ podman build -f yop.Dockerfile
STEP 1: FROM scoulomb/docker-doctor:dev
Getting image source signatures
Copying blob b8b1fecc905c done
Copying blob 7a14fb4cd302 done
Copying blob 75ac8019c973 done
Copying blob 916d01923d2b done
Copying blob 2434aab92f51 done
Copying blob 76bb19b4b3e1 done
Copying blob e0b99f2f5cd7 done
Copying blob 817a58832021 done
Copying config fcaf5c2e6f done
Writing manifest to image destination
Storing signatures
STEP 2: RUN ["/bin/echo", "hello"]
hello
STEP 3: COMMIT
--> 681c60f5d24
681c60f5d2491dba04fd2058bdf8b0fa1e8ac83eea7b84bf05e1638e2207635f
````

See [container engine and podman produces OCI compliant image](../../container-engine/container-engine.md).

#### How to fix the issue in ArchLinux?

<!-- add 2020-01-11 -->
 
<!-- here it was error with real automation
````shell script
ERRO[0000] container_linux.go:370: starting container process caused: exec: "/bin/sh": stat /bin/sh: no such file or directory
````
-->

From https://github.com/moby/moby/issues/33266
> The solution was to do a Factory Reset in Docker. I had to remember to re-check the exposure of port 2375 over TLS.

Pruning was not sufficient. See:
- https://docs.docker.com/engine/reference/commandline/system_prune/

````shell script
docker system prune --all
````
To fix the error we have to remove docker

Cf. https://stackoverflow.com/questions/62173586/docker-where-is-reset-to-factory-defaults-on-linux

````shell script
# reset docker
sudo pacman -R docker-compose
sudo pacman -R docker
sudo rm -rf /var/lib/docke
````
and reinstall it

````shell script
vagrant up --provision
````

Then we another error:

````shell script
➤ cat yop.Dockerfile
FROM scoulomb/docker-doctor:dev

RUN ["/bin/echo", "hello"]
ENTRYPOINT ["/bin/echo", "hello"]
[20:20] ~
➤ sudo podman build -f yop.Dockerfile -t test
STEP 1: FROM scoulomb/docker-doctor:dev
Error: error creating build container: short-name "scoulomb/docker-doctor:dev" did not resolve to an alias and no unqualified-search registries are defined in "/etc/containers/registries.conf"
````

You may also want to login to docker 

````shell script
podman login docker.io
````

But the actual fix is to specify the path 

````shell script
➤ cat yop.Dockerfile
FROM docker.io/scoulomb/docker-doctor:dev

RUN ["/bin/echo", "hello"]
ENTRYPOINT ["/bin/echo", "hello"]
[20:21] ~
➤ sudo podman build -f yop.Dockerfile -t test
STEP 1: FROM docker.io/scoulomb/docker-doctor:dev
STEP 2: RUN ["/bin/echo", "hello"]
--> Using cache f0ad260d9eb241d9b43ecf461e81beede485b12f6ce8447591afa465ebaf1bd4
--> f0ad260d9eb
STEP 3: ENTRYPOINT ["/bin/echo", "hello"]
--> Using cache 16794034f37147698d62881ab2e817babf6a4c2daf6219dd2e5ea3384b9e8751
STEP 4: COMMIT test
--> 16794034f37
16794034f37147698d62881ab2e817babf6a4c2daf6219dd2e5ea3384b9e8751
````

For Python it would be `FROM docker.io/python:3.9.0`.

Then run 

````shell script
➤ sudo podman run test
hello
````

If you have this error

````shell script
Error: error creating build container: Error committing the finished image: error adding layer with blob "sha256:756975cb9c7e7933d824af9319b512dd72a50894232761d06ef3be59981df838": Error processing tar file(exit status 1): potentially insufficient UIDs or GIDs available in user namespace (requested 0:42 for /etc/gshadow): Check /etc/subuid and /etc/subgid: lchown /etc/gshadow: invalid argument
````

Do instruction from: https://serverfault.com/questions/738773/docker-failed-to-add-the-pair-interfaces-operation-not-supported
> In my case, the error appears every time I update my Linux kernel. It disappears when I restart the computer.
> I am using Arch Linux

<!-- in fact did it with real auto but global error -->

Finally note we can not use sha (for sha, see [Issue 3](#issue-3-default-python-version-change-to-39))
Otherwise we have 

````shell script
➤ cat yop.Dockerfile
FROM docker.io/scoulomb/docker-doctor:dev@sha256:2b4763a7d40a8314397d70fe7de788677a9ebaad82c37c9963ca8effa415f787

RUN ["/bin/echo", "hello"]
ENTRYPOINT ["/bin/echo", "hello"]
[20:15] ~
➤ sudo podman build -f yop.Dockerfile -t test
STEP 1: FROM docker.io/scoulomb/docker-doctor:dev@sha256:2b4763a7d40a8314397d70fe7de788677a9ebaad82c37c9963ca8effa415f787
Error: error creating build container: Docker references with both a tag and digest are currently not supported
````

<!-- 
dns auto worked but then pipenv issue (user) when run 
ModuleNotFoundError: No module named 'connexion'
could run it with docker via a local registry, not tried: https://www.australtech.net/running-a-local-docker-registry/
(and also done Setup/ClusterSetup/LocalRegistrySetup)
made both my image and dns auto in parallel ==> OK 
STOP HERE for NOW OK STOP
-->

#### Workaround 4: use rsync instead of nfs

In vagrant file change commented line to 

````shell script
# config.vm.synced_folder 'C:\Users\<user>\dev', '/home/vagrant/dev', type: "nfs", disabled: false
config.vm.synced_folder 'C:\Users\<user>\dev', '/home/vagrant/dev', type: "rsync", disabled: false, rsync__exclude: "*.git"
````

See doc here: https://www.vagrantup.com/docs/synced-folders/rsync#rsync

````shell script
vagrant halt
vagrant up
vagrant ssh
cd ~/dev/my-automation
````

````shell script
➤ docker build . -f service.dockerfile -t api-server
Sending build context to Docker daemon  3.542MB
Step 1/13 : FROM python:3.8.5-slim@sha256:282fc7428f74cf3317d78224349b9215f266fc9cb4197cce58dad775cb565ed3
sha256:282fc7428f74cf3317d78224349b9215f266fc9cb4197cce58dad775cb565ed3: Pulling from library/python
bf5952930446: Already exists
385bb58d08e6: Already exists
ab14b629693d: Already exists
7a5d07f2fd13: Already exists
25a245937421: Already exists
Digest: sha256:282fc7428f74cf3317d78224349b9215f266fc9cb4197cce58dad775cb565ed3
Status: Downloaded newer image for python:3.8.5-slim@sha256:282fc7428f74cf3317d78224349b9215f266fc9cb4197cce58dad775cb565ed3
 ---> 38cd21c9e1a8
Step 2/13 : WORKDIR /working_dir
 ---> Running in c4bf92f1a4e6
````

And it worked :).

Now it has 2 disadvantages:
- The sync is unidirectionnal, from host to guest VM. 

    - As a consequence we can not use git from VM, therefore I propose to remove git file to speed up the sync.
Even worse if start creating branch on VM it would be overriden by rsync. (can use conemu git bash or Pycharm term)
    - If your script produces output such as text file/html page you have  no direct access. You can start a simple http server to retrieve your results:
    See real case [here](https://github.com/scoulomb/myDNS/blob/master/3-DNS-solution-providers/1-Infoblox/6-Infoblox-error-management/infoblox_api_content_type.md#run-test).
    
    
- To be synced we need to run `vagrant rsync` or `vagrant rsync-auto`, to watch the folder. See doc:https://www.vagrantup.com/docs/cli/rsync-auto
An initial sync is done at `vagrant up` time after `halt` (`vagrant halt`, `vagrant up`).

<!-- if not sync is mentionned by default:  /vagrant => C:/Users/scoulombel/dev/dev_vm -->

Note I tried SMB but it requires the publing :https://www.vagrantup.com/docs/synced-folders/smb
<!-- ssl issue again as for config.disksize.size -->

Some tips to commit from windows. Use credentials manager:https://cmatskas.com/how-to-update-your-git-credentials-on-windows/

Go to `Control Panel\User Accounts\Credential Manager` and update password in control panel or remove it to be re-prompted again.

<!-- this file concluded include link other repo suffit --> 

**I will use workaround 4 for remaining of this file**

**Tips**: as sync is one way VM/Guest, if you need to get output files or view file (like html test resport), you can start a Python server:

````shell script
python -m http.server 8080
````

and go browser at [localhost:9080](localhost:9080).

## Issue 3: Default Python version change to 3.9

Python 3.9 is now the default in new Archlinux release.

````shell script
➤ pipenv run python run.py --verbose --no-json-logs
Warning: Python 3.8 was not found on your system...
Neither 'pyenv' nor 'asdf' could be found to install Python.
You can specify specific versions of Python with:
$ pipenv --python path/to/python
````

Edit pipfile (and do not forget to align Dockerfile)

````shell script
[requires]
python_version = "3.9"
````

Then do 

````shell script
vagrant rsync
````

Followed by


````shell script
pipenv update
pipenv run python run.py --verbose --no-json-logs
````

<!-- this hampered after reprovisionned the machine -->

This `pipenv update` requires to install python 3.9 on windows) as one way rsync with workaround 4.
And then edit your Dockerfile.

````shell script
FROM python:3.9.0-slim
````

````shell script
vagrant rsync
docker-compose up --build # yse --build to force rebuild
````

We can set a version 

````shell script
➤ docker inspect ( docker images | grep python | grep 3.9.0-slim | awk '{print $3}') | head -n 10
[
    {
        "Id": "sha256:338d84dcd01719111dd8d1f650be9d6b5df042bf4a810921c7213d98913cbe05",
        "RepoTags": [
            "python:3.9.0-slim"
        ],
        "RepoDigests": [
            "python@sha256:de8d4a338fb815509de2046cea4ff48959c84aabc1b65cb41c5e2da1ac599b04"
        ],
        "Parent": "",
````

Thus we use the `RepoDigests` and not the `Id`

````shell script
FROM python:3.9.0-slim@sha256:de8d4a338fb815509de2046cea4ff48959c84aabc1b65cb41c5e2da1ac599b04
````

And then

````shell script
vagrant rsync
docker-compose up --build # use --build to force rebuild
````

Note issue with pylint

````shell script
disable=
[...]
# Python 3.9 issue: https://github.com/PyCQA/pylint/issues/3882, to be removed when 3882 delivered
# Tracked by: https://rndwww.nce.amadeus.net/agile/browse/NWAUTO-957
    unsubscriptable-object
````


<!-- see DNS pr#86 -->

## Other running code + non-regression 

````shell script
docker-compose up
````

### Issue A:  Some permissions issue with workaround 4

We can have this error:

````shell script
my-non-regression_1     | [ERROR] Failed to execute goal org.apache.maven.plugins:maven-resources-plugin:2.6:testResources (default-testResources) on project myprok_Non_Regression: /working_dir/target/test-classes/myproj/mytest.feature (Permission denied) -> [Help 1]
````

To fix the issue do 

````shell script
docker rmi myproj-non-regression --force
rm -rf ~/dev/my-automation
vagrant rsync
chmod -R 777 ~/dev/myautomation
sudo systemd-resolve --flush-caches
````

<!-- I suspect this to happen when doing rm -rf non_regression/target/ --> 
<!--
vpn auth failure change exp pwd
-->

### Issue B

Socket timeout in non reg 

````shell script
com.intuit.karate.exception.KarateException: mysupertest.feature:100 - 
create_something.feature:18 - 
java.net.SocketTimeoutException: Read timed out
````

Best fix is to change the device
<!-- see DNS PR#87 -->
and device could not not support big workload so we (this has great impact) 
- increase connection timeout (karate config file) and read timeout (see https://github.com/scoulomb/http-over-socket, match ok)
- and reduce number of test in parallel (had to go 1) (java file).
It fixed most of the run but some still failing.

We can also increase connection and read timeout when request library:
https://stackoverflow.com/questions/24784665/python-requests-module-connection-timeout (tuple or int).
    
Also if we have several cronjob running nightly of different phase at same time, and targeting same device.
It could cause similar issues. We could add template parameter for cron pattern and spread in time.
-> it was not necessary 

We could make workload tests on device via: /repos/stress_test.
<!-- see DNS PR#88 -->

