## Bash one-liners

A collection of useful bash one-liners for blue team operations includes commands for system information, process monitoring, and network analysis.


## Timestamp

To display the current date, time, and timezone in a bash prompt, use the following configuration in the `.bashrc` file:

```bash
PS1='\\[\\033[00;35m\\][`date +"%d-%b-%y %T %Z"]` ${PWD#"${PWD%/*/*}/"}\\n\\[\\033[01;36m\\]-> \\[\\033[00;37m\\]'
```


🕵️‍♂️ “Stay alert, stay patched.”
