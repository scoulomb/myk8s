# Repo amangement

I would like to change the author of git commit and commit with the user not in the gitconfig

## Rewrite author 

### Step 0: Back up old repo to `myk8-old`

### Step 1: clone tmp repo from github

````
git clone https://github.com/scoulomb/myk8s.git myk8s-tmp
cd myk8s-tmp
````

### Rewrite history with good email


Change author with an interactive rebase

This is explained here:
- https://stackoverflow.com/questions/750172/how-to-change-the-author-and-committer-name-and-e-mail-of-multiple-commits-in-gi


````
git rebase -i -p 7103ace3f15326050b9536961a6fc4e746f67109 #<some HEAD before all of your bad commits>
````

Then mark all of your bad commits as "edit" in the rebase file. If you also want to change your first commit, you have to manually add it as first line in the rebase file (follow the format of the other lines). Then, when git asks you to amend each commit, do
We can use `esc`, `:%s/pick/edit/g`
and exit vi `:wq`.


And for each commit:

````
git commit --amend --author "Sylvain COULOMBEL <sylvaincoulombel@gmail>" --no-edit && \
git rebase --continue
````

In my case I had 40 commit so we can automate the keyboard press doing 

https://askubuntu.com/questions/338857/automatically-enter-input-in-command-line


````
for i in `seq 1 45`;
do
    echo $i
	git commit --amend --author "Sylvain COULOMBEL <sylvaincoulombel@gmail>" --no-edit && git rebase --continue
done

````

Check `git logs`


push this repo 

````		
git push --force
````

I did not rewrite first commit but no-reply one so ok.
Note the fact we amened will make github show `authored and committed`
And comit after the rebase appears correctly because mail used is matching the one it github online settings.


## Configure local user


As per doc here
- https://stackoverflow.com/questions/19840921/override-configured-user-for-a-single-git-commit
- https://stackoverflow.com/questions/8801729/is-it-possible-to-have-different-git-configuration-for-different-projects


````
git config user.name "Sylvain COULOMBEL"
git config user.email "sylvaincoulombel@gmail.com"
````

This will edit the conf in `.git` folder  
Note `--global` is not there.

````
$ cat .git/config
[core]
        repositoryformatversion = 0
        filemode = false
        bare = false
        logallrefupdates = true
        symlinks = false
        ignorecase = true
[remote "origin"]
        url = https://github.com/scoulomb/myk8s.git
        fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
        remote = origin
        merge = refs/heads/master
[user]
        name = Sylvain COULOMBEL
        email = sylvaincoulombel@gmail.com

````


## Commit in past 

https://stackoverflow.com/questions/3895453/how-do-i-make-a-git-commit-in-the-past

````shell
git commit --date "10 day ago" -m "Your commit message"  # or copy past date format from git log
````