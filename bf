#!/usr/bin/env bash

# Ensure we have the right directory
HERE=$(dirname $0)

# Load libs
. $HERE/stack.sh


# Define globals
declare -a ops=()
stack_init stack
stack_init jumps

# Define functions
add-to-ops() {
  local op_name=$1
#  ops+=="$op_name;1;0"
  local id="ops_${#ops[@]}"
  declare -A "$id"
  declare -n op="$id"
  op[name]=$op_name
  op[operand]=1
  ops+=("$id")
  echo "add-to-ops: new len is ${#ops[@]}"
}

get-ops-element() {
  index=$1
  last_record_name="${ops[-1]}"
  echo "last_record_name: ${last_record_name}"
  local id="ops_${index}"
  declare -A "$id"
  echo "id: ${id}"
  declare -n op="$id"
  echo "ops[$index][name]: ${op[name]}"
  echo "ops[$index][operand]: ${op[operand]}"
}

add-op-to-ops() {
  local op_name=$1
  local len=${#ops[@]}
  local last=$(( len - 1 ))
  if [[ $len -gt 0 ]]; then
    last_record_name="${ops[-1]}"
    declare -n last_record="$last_record_name"
    # echo "last_record: ${last_record[name]}"
    if [[ ${last_record[name]} == $op_name ]]; then
      if [[ $op_name == "jz" || $op_name == "jnz" ]]; then
        add-to-ops $op_name
      else
        (( last_record[operand]++ ))
      fi
    else
      add-to-ops $op_name
    fi
  else
    add-to-ops $op_name
  fi
}

add-to-stack() {
  local a="$1"
  local b="$2"
  local pair=("$a" "$b")
  stack_push_array stack pair
}

rotate-last-to-front() {
    local -n arr=$1
    local last_element

    ((${#arr[@]})) || return 0

    last_element="${arr[-1]}"
    arr=("$last_element" "${arr[@]:0:${#arr[@]}-1}")
}

parse-instructions() {
  local source=("$@")
  local word=''
  local i=0, c=0, head=0
  declare -a memory=()

  for (( i=0; i<1024; ++i)); do
    memory+=(0)
  done

  for word in ${source[@]}; do
    for (( j=0; j<${#word}; j++ )); do
      char="${word:$j:1}"
      # local op
      declare -A op
      case $char in
        +)
          c=$char
          # (( memory[head] += 1 ))
          add-op-to-ops "plus"
          ;;
        -)
          c=$char
          # (( memory[head] -= 1 ))
          add-op-to-ops "minus"
          ;;
        '<')
          c=$char
          add-op-to-ops "left"
          # (( head -= 1 ))
          ;;
        '>')
          c=$char
          add-op-to-ops "right"
          (( head += 1 ))
          ;;
        '[')
          c=$char
          add-op-to-ops "jz"
          add-to-stack ${#ops[@]} 0
          ;;
        ']')
          c=$char
          add-op-to-ops "jnz"
          local len=${#ops[@]}
          declare -a last_element
          stack_pop_array stack last_element
          echo "len: $len, last_element: ${last_element[@]}, le_len: ${#last_element[@]}"
          last_element=("${last_element[0]}" "$len")
          stack_push_array jumps last_element
          ;;
        .)
          c=$char
          add-op-to-ops "out"
          # printf "\\x$(printf '%02x' "${memory[$head]}")"
          ;;
        ,)
          c=$char
          add-op-to-ops "in"
          #read -rn 1 $char
          #local d=$(printf '%d' "'$char")
          #(( memory[head] = d ))
          ;;
        *)
          c=0
          ;;
      esac
      [[ $c == 0 ]] || echo -n $c
    done
  done
  echo
  while true; do
    declare -a el 
    stack_pop_array jumps el
    #echo "element of stack: $inner"
    #local sta="${inner[0]}"
    #local end="${inner[1]}"
    echo "el: ${#el[@]}"
    local sta="${el[0]}"
    local end="${el[1]}"
    echo "sta: $sta, end: $end"
    
    get-ops-element $sta

    declare -n record=$ops["ops_$sta"]
    declare -A "$id"
    echo "record: ${record[@]}"
    echo "record[operand]: ${record[operand]}"
    record[operand]=$end
  done
  for record_name in "${ops[@]}"; do
    declare -n record="$record_name"
    printf 'name: %s\n' "${record[name]}"
    printf 'operand: %s\n' "${record[operand]}"
    printf '\n'
  done
}

run-brainfuck-script() {
  local filename=$1
  echo "Running $filename"
  local source=$(cat $filename)
  echo ${source[@]}
  # source will be an array of lines
  parse-instructions ${source[@]}
  return 0
}


# Main script starts here

# Check we are running bash version 5 (macOS is still running version 3 in 2026...)
header=$(/usr/bin/env bash --version |head -n 1| sed -E -e's/GNU bash, version (.*) \(.*/\1/g')
major="${header%%.*}"
if [[ $major < 5 ]]; then
  echo "This script needs bash version 5"
  exit 1
fi


filenames=()
argc=$#
option=$1
shift

for ((i=0; i<argc; ++i)); do
  case $option in
    --no-jit) 
      echo "JIT is not supported, anyways :P"
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
  echo $filename
  if [[ -f $filename ]]; then 
    run-brainfuck-script $filename
  else
    echo "File not found error: $filename"
  fi
done

