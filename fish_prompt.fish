function agnoster::set_default
  set name $argv[1]
  set -e argv[1]
  set -q $name; or set -g $name $argv
end

agnoster::set_default AGNOSTER_SEGMENT_SEPARATOR '' \u2502
agnoster::set_default AGNOSTER_SEGMENT_RSEPARATOR '' \u2502

agnoster::set_default AGNOSTER_ICON_ERROR \u2717
agnoster::set_default AGNOSTER_ICON_ROOT \u2713
agnoster::set_default AGNOSTER_ICON_SUCCESS \u03BB
agnoster::set_default AGNOSTER_ICON_BGJOBS \u2699

agnoster::set_default AGNOSTER_ICON_SCM_BRANCH \u2387
agnoster::set_default AGNOSTER_ICON_SCM_REF \u27a6
agnoster::set_default AGNOSTER_ICON_SCM_STAGED '…'
agnoster::set_default AGNOSTER_ICON_SCM_STASHED '~'

function agnoster::segment --desc 'Create prompt segment'
  set bg $argv[1]
  set fg $argv[2]
  set -e argv[1 2]
  set content $argv

  set_color -b $bg

  if set -q __agnoster_background; and [ "$__agnoster_background" != "$bg" ]
    set_color "$__agnoster_background"; echo -n "$AGNOSTER_SEGMENT_SEPARATOR[1]"
  end

  if [ -n "$content" ]
    set -g __agnoster_background $bg
    set_color -b $bg $fg
    echo -n " $content"
  end
end

function agnoster::context
  set user (whoami)
  set host (hostname)
  if [ "$user" != "$DEFAULT_USER" ]; or [ -n "$SSH_CLIENT" ]
    agnoster::segment black bryellow "$user@$host "
  end

  if [ ! -z "$IN_NIX_SHELL" ]
    agnoster::segment red black "nix "
  end
end

# Status:
# - was there an error
# - am I root
# - are there background jobs?
function agnoster::status
  if [ "$__agnoster_last_status" -ne 0 ]
    set icons $icons "$AGNOSTER_ICON_ERROR"
  end
  if [ (id -u $USER) -eq 0 ]
    set icons $icons "$AGNOSTER_ICON_ROOT"
  end
  if [ (jobs -l | wc -l) -ne 0 ]
    set icons $icons "$AGNOSTER_ICON_BGJOBS"
  end
  
  if set -q icons
    agnoster::segment black red "$icons "
  end

  # Put this check after so it'll override the black red segment
  if [ "$__agnoster_last_status" -eq 0 ]
    set icons $icons "$AGNOSTER_ICON_SUCCESS"
    agnoster::segment black yellow "$icons "
  end
end

function agnoster::errorstatus
  if [ "$__agnoster_last_status" -ne 0 ]
    set icons $icons "$AGNOSTER_ICON_ERROR"
  end
  if set -q icons
    agnoster::segment black red \u2717 "$__agnoster_last_status"
  end
end

# Git {{{
# Utils {{{
function agnoster::git::is_repo
  command git rev-parse --is-inside-work-tree ^/dev/null >/dev/null
end

function agnoster::git::color
  if command git diff --no-ext-diff --quiet --exit-code
    echo "blue"
  else
    echo "yellow"
  end
end

function agnoster::git::branch
  set -l ref (command git symbolic-ref HEAD ^/dev/null)
  if [ "$status" -ne 0 ]
    set -l branch (command git show-ref --head -s --abbrev | head -n1 ^/dev/null)
    set ref "$AGNOSTER_ICON_SCM_REF $branch"
  end
  echo "$ref" | sed "s|\s*refs/heads/|$AGNOSTER_ICON_SCM_BRANCH |1"
end

function agnoster::git::ahead
  command git rev-list --left-right '@{upstream}...HEAD' ^/dev/null | \
    awk '
      />/ {a += 1}
      /</ {b += 1}
      {if (a > 0 && b > 0) nextfile}
      END {
        if (a > 0 && b > 0)
          print "±";
        else if (a > 0)
          print "+";
        else if (b > 0)
          print "-"
      }'
end

function agnoster::git::stashed
  command git rev-parse --verify --quiet refs/stash >/dev/null; and echo -n "$AGNOSTER_ICON_SCM_STASHED"
end

function agnoster::git::staged
  command git diff --cached --no-ext-diff --quiet --exit-code; or echo -n "$AGNOSTER_ICON_SCM_STAGED"
end

function agnoster::git -d "Display the actual git state"
  agnoster::git::is_repo; or return

  set -l staged  (agnoster::git::staged)
  set -l stashed (agnoster::git::stashed)
  set -l branch (agnoster::git::branch)
  set -l ahead (agnoster::git::ahead)

  set -l content "$branch$ahead$staged$stashed"

  set_color yellow; echo -n "$AGNOSTER_SEGMENT_SEPARATOR[2]"
  agnoster::segment (agnoster::git::color) black "$content "
end
# }}}

function agnoster::seperator
  set_color yellow;
  if test -d .git
    set_color black;
  end
  echo -n "$AGNOSTER_SEGMENT_SEPARATOR[2]"
  agnoster::segment black yellow "=> "
end

function agnoster::exectime
  set exclude_cmd "bash|less|man|more|ssh|fish|ls|cd"
  set minimum_duration 10000
  if begin
    if test $CMD_DURATION -gt $minimum_duration
      and echo $history[1] | grep -vqE "^($exclude_cmd).*"
        set duration (echo "$CMD_DURATION 1000" | awk '{printf "%.1fs", $1 / $2}')
        set_color yellow; echo -n "$AGNOSTER_SEGMENT_SEPARATOR[2]"
        agnoster::segment yellow black "$duration"
    end
   end
  end
end

function agnoster::dir -d 'Print current working directory'
  set -l dir (prompt_pwd)
  if set -q AGNOSTER_SEGMENT_SEPARATOR[2]
    set dir (echo "$dir" | sed "s,/,$AGNOSTER_SEGMENT_SEPARATOR[2],g")
  end
  agnoster::segment cyan black "$dir"
  set_color black; echo -n "$AGNOSTER_SEGMENT_SEPARATOR[2]"
end

function agnoster::finish
  agnoster::segment normal normal
  echo -n ' '
  set -e __agnoster_background
end

function fish_prompt
  set -g __agnoster_last_status $status

  #agnoster::context
  agnoster::dir
  agnoster::status
  agnoster::git
  agnoster::seperator
  agnoster::exectime
  agnoster::errorstatus
  agnoster::finish

  set_color normal
  set_color -b normal
end
