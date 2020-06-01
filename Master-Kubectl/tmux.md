# TMux basics

<!--
Using Ubuntu (HP) with qwerty keyboard.
-->

## Setup

`sudo apt-get install tmux`

## Start tmux server

**- `tmux`: Start tmux server and new session**

## TMux commands

**Before any command do: `CTRL+B+`**


### tmux multi-window

#### Window creation

- `c`: **Crearte a new Window and go to it**
-  `,`: remame Window

#### Window navigation

- `n`: **switch between terminal**
- `2`: Go to terminal 2 (can be any number)
- `w`: Open terminal selection pane  

#### Window deletion

- `x`: **Kill current Window**
<!--
(not confuse where x is term nb in some doc)
-->
- or `:` `kill-window -t 1`: Kill Window 1

### tmux split

#### Split creation

- Those will create within current terminal (or split), a new split and start a new terminal
   - **`"`: vertical split**
   - `%`: horizontal split

#### Split navigation
- `o`: **Navigate within splits**
- `Alt + (directional arrows)`: Resize split


#### Split deletion

- `!`: **back to a single terminal**


### Leave tmux

- `:` `kill-session` : Leave tmux or **kill all windows. See [Window deletion](#Window-deletion).**
- `d`: **leave tmux and keep session**


## Reattach a session

- `tmux attach`: **attach last tmux session**
- `tmux ls`: list active session 
- `tmux attach -t 1` : Attach to session 1 (note if a session contains several terminal will come back to current terminal). See [start Tmux](#Start-tmux-server)

## Sources

- http://denisrosenkranz.com/tuto-introduction-a-tmux-terminal-multiplexer/
- https://superuser.com/questions/777269/how-to-close-a-tmux-session
- https://stackoverflow.com/questions/7771557/how-to-terminate-a-window-in-tmux
