# Fix Line separator issue

From this [doc](https://stackoverflow.com/questions/40470895/phpstorm-saving-with-linux-line-ending-on-windows):
- Go to `Pycharm > File >  File properties > Line separators > LF`
- `ctrlx,ctrlv`

Note sometime scripts will not run because of this
If issue with git, check [this](https://stackoverflow.com/questions/2517190/how-do-i-force-git-to-use-lf-instead-of-crlf-under-windows
). It is the reason in [README](./README.md#Prerequisite) we choose `LF`.

