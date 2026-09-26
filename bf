#!/usr/bin/env bash

# Ensure we have the right directory
HERE=$(dirname $0)

# Define globals
declare -a ops=()
declare -a stack=()
declare -a jumps=()
#
# Define functions
#
# ops is an array with formated values "op-name;operand"
# op-name is the operation like inc
# operand is the number of repetition of this operation
# so "inc;8" is ++++++++ 
# by default the count is 1.
#
# special cases for jz and jnz where stack and jumps arrays are used to backpatch the brainfuck code


# Debug function
echo_d() {
  if [[ $DEBUG != "" ]]; then
    echo $@
  fi
}

# Add an operation to the list of operations
add-to-ops() {
  local op_name=$1
  local operand
  if [[ $2 == "" ]]; then
    operand=1
  else
    operand="$2"
  fi
  local data="$op_name;$operand"
  ops+=("$data")
  # echo_d "add-to-ops: new len is ${#ops[@]}"
  # echo_d "  we've just add to ops: ${ops[-1]} from $data"
}

# Replace the jump target with the given value
replace-ops-with() {
  jump_target="$1"

  echo_d "replace-ops-with: $jump_target"
  local needle=";"
  sta=${jump_target%%"$needle"*}
  end=${jump_target#*"$needle"}

  local op="${ops[sta]}"
  ope=${op%%"$needle"*}
  ops[$sta]="$ope;$end"
  echo_d "op: $op, new op: $ope;$end"
}


# Add an operation to the list of operations
# This version is proxy to add-to-ops that eventually will manage the packing of consecutive identical instructions
# TODO: not implemented yet
add-op-to-ops() {
  local op_name="$1"
  add-to-ops "$op_name"
}


# add a pair to the stack array
add-to-stack() {
  local a="$1"
  local b="$2"
  echo_d "add-to-stack($a, $b)" 
  local data="$a;$b"
  stack+=("$data")
  echo_d "add-to-stack: new len is ${#stack[@]}"
  local last_element="${stack[-1]}"
  echo_d "  we've just added $last_element -> $data" 
}


# Memorize the current current index as the destination of the previous jz instruction for backpatching later
# Retreive the jz index to patch the jnz destination index.
replace-last-destination-jump-index() {
  local last_element="${stack[-1]}"
  local needle=";"
  sta=${last_element%%"$needle"*}
  end=${last_element#*"$needle"}
  echo_d "sta: $sta, end: $end"
  if [[ $end != "0" ]]; then
    echo_d "ERROR: end should be 0 here!"
    exit 1
  fi
  let actual_index="${#ops[@]}"
  end="$actual_index"
  local data="$sta;$end"

  echo_d "replace-last-destination-jump-index(): $last_element --> $data"
  jumps+=("$data")
  unset 'stack[-1]'

  # Now the jnz is still pointing to 1, it must be pointing to the corresponding jz (sta)
  # remove the jnz we've just added, not great, but will do for now.
  unset 'ops[-1]'
  # Add back the jnz with
  add-to-ops 'jnz' "$sta"
}


# Main function for brainfuck source parsing
parse-instructions() {
  local source=("$@")
  local word=''
  local i=0, c=0
  for word in ${source[@]}; do
    for (( j=0; j<${#word}; j++ )); do
      char="${word:$j:1}"
      # local op
      declare -A op
      case $char in
        +)
          c=$char
          add-op-to-ops "inc"
          ;;
        -)
          c=$char
          # (( memory[head] -= 1 ))
          add-op-to-ops "dec"
          ;;
        '<')
          c=$char
          add-op-to-ops "left"
          # (( head -= 1 ))
          ;;
        '>')
          c=$char
          add-op-to-ops "right"
          # (( head += 1 ))
          ;;
        '[')
          c=$char
          add-to-stack "${#ops[@]}" 0
          add-op-to-ops "jz"
          ;;
        ']')
          c=$char
          add-op-to-ops "jnz"
          replace-last-destination-jump-index
         ;;
        .)
          c=$char
          add-op-to-ops "out"
          ;;
        ,)
          c=$char
          add-op-to-ops "in"
          ;;
        *)
          c=0
          ;;
      esac
      [[ $c == 0 ]] || echo_d -n $c
    done
  done
  echo_d
  echo_d "Backpatching jumps..."
  while [[ ${#jumps[@]} -gt 0 ]]; do
    local last_jump="${jumps[-1]}"
    replace-ops-with "$last_jump"
    unset 'jumps[-1]'
  done
  echo_d "Done.. Backpatching jumps."

  if [[ $DEBUG != "" ]]; then
    local i=0;
    for record_name in "${ops[@]}"; do
      # declare -n record="$record_name"
      printf '%03d: name: %s\n' $i "${record_name}"
      (( i++ ))
      # printf 'operand: %s\n' "${record[operand]}"
      # printf '\n'
    done
  fi
}
 

# Main function for brainfuck execution
execute-brainfuck() {
  local head=0
  declare -a memory=()

  for (( i=0; i<1024; ++i)); do
    memory+=(0)
  done
  local ip=0
  local needle=";"

  while [[ $ip -lt ${#ops[@]} ]]; do
    local ope="${ops[ip]}"
    local op=${ope%%"$needle"*}
    local operand=${ope#*"$needle"}
    echo_d "TRACE: ip: $ip, Op: $op;$operand; head: $head, mem: ${memory[head]}"
    case $op in
      inc)
        (( memory[head]=memory[head]==255 ? 0 : memory[head]+1 ))
        ;;
      dec)
        (( memory[head]=memory[head]==0 ? 255 : memory[head]-1 ))
        ;;
      left)
        (( head -= 1 ))
        ;;
      right)
        (( head += 1 ))
        ;;
      jz)
        if [[ ${memory[head]} -eq 0 ]]; then
          (( ip = operand ))
          continue
        fi
        ;;
      jnz)
        if [[ ${memory[head]} -ne 0 ]]; then
          (( ip = operand+1 ))
          continue
        fi
        ;;
      out)
        printf "\\x$(printf '%02x' "${memory[$head]}")"
        ;;
      'in')
        local char
        read -rn 1 char
        local d=$(printf '%d' "'$char")
        (( memory[head] = d ))
        ;;
    esac
    (( ip++ ))
  done
}


# Chain loading, parsing and executing brainfuck script
run-brainfuck-script() {
  local filename=$1
  echo_d "Running $filename"
  local source=$(cat $filename)
  echo_d ${source[@]}
  # source will be an array of lines
  parse-instructions ${source[@]}
  execute-brainfuck
  return 0
}


# End of function declarations

# Check we are running bash version 5 (macOS is still running version 3 in 2026...)
header=$(/usr/bin/env bash --version |head -n 1| sed -E -e's/GNU bash, version (.*) \(.*/\1/g')
major="${header%%.*}"
if [[ $major < 5 ]]; then
  echo_d "This script needs bash version 5"
  exit 1
fi


filenames=()
argc=$#
option=$1
shift

for ((i=0; i<argc; ++i)); do
  case $option in
    --no-jit) 
      echo_d "JIT is not supported, anyways :P"
      option=$1
      shift
      ;;
    *)
      filenames+=($option)
      option=$1
      shift
      ;;
  esac
done

for filename in ${filenames[@]}; do
  echo_d $filename
  if [[ -f $filename ]]; then 
    run-brainfuck-script $filename
  else
    echo_d "File not found error: $filename"
  fi
done

