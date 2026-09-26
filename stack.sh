#!/usr/bin/env bash
#
# stack.sh - A reusable Stack "object" for bash scripts, extended to
# support storing arrays and associative arrays as elements.
#
# Bash arrays can only hold scalar strings, so a real array can never
# be nested as one element of another array. This library offers two
# ways around that:
#
#   1. BY REFERENCE (stack_push_ref / stack_pop_ref)
#      Push the NAME of an existing array/assoc array variable onto
#      the stack. On pop, bind a nameref to that name to access it.
#      Fast, no copying, but the referenced variable must stay alive
#      and in scope for as long as you need it.
#
#   2. SERIALIZED (stack_push_array / stack_pop_array,
#                  stack_push_assoc / stack_pop_assoc)
#      Flatten the array's contents into one string (using a control
#      character as separator that's very unlikely to appear in real
#      data) and store that string as the stack element. On pop,
#      reconstruct a fresh array/assoc array from it. Self-contained,
#      safe to persist/pass around, but copies the data.
#
# Requires bash 4.3+ (nameref / `local -n`).
#
# Usage:
#   source stack.sh
#
#   --- scalars (original API) ---
#   stack_init s
#   stack_push s "a" "b"
#   stack_pop  s val
#
#   --- arrays, by reference ---
#   fruits=("apple" "banana" "cherry")
#   stack_push_ref s fruits
#   stack_pop_ref  s name
#   declare -n ref="$name"
#   echo "${ref[@]}"
#
#   --- arrays, serialized (self-contained) ---
#   stack_push_array s fruits
#   stack_pop_array  s restored
#   echo "${restored[@]}"
#
#   --- associative arrays, serialized ---
#   declare -A person=( [name]="Xvolks" [city]="Nievroz" )
#   stack_push_assoc s person
#   declare -A restored_person
#   stack_pop_assoc s restored_person
#   echo "${restored_person[name]}"

# Separator used for serialization. Unit Separator (0x1F) is a control
# character essentially never present in normal text, unlike comma/space.
_STACK_SEP=$'\x1f'

# ---------------------------------------------------------------------
# Core scalar stack (also used as backing store for refs/serialized data)
# ---------------------------------------------------------------------

# stack_init <stack_name>
stack_init() {
    local -n _stk="$1"
    _stk=()
}

# stack_push <stack_name> <value> [value2 ...]
stack_push() {
    local -n _stk="$1"
    shift
    _stk+=("$@")
}

# stack_pop <stack_name> [out_var]
stack_pop() {
    local -n _stk="$1"
    local _out_var="$2"
    local _n=${#_stk[@]}

    if (( _n == 0 )); then
        echo "stack_pop: stack '$1' is empty" >&2
        return 1
    fi

    local _val="${_stk[_n-1]}"
    unset '_stk[_n-1]'
    _stk=("${_stk[@]}")

    if [[ -n "$_out_var" ]]; then
        printf -v "$_out_var" '%s' "$_val"
    else
        printf '%s\n' "$_val"
    fi
}

# stack_peek <stack_name> [out_var]
stack_peek() {
    local -n _stk="$1"
    local _out_var="$2"
    local _n=${#_stk[@]}

    if (( _n == 0 )); then
        echo "stack_peek: stack '$1' is empty" >&2
        return 1
    fi

    local _val="${_stk[_n-1]}"

    if [[ -n "$_out_var" ]]; then
        printf -v "$_out_var" '%s' "$_val"
    else
        printf '%s\n' "$_val"
    fi
}

# stack_size <stack_name> [out_var]
stack_size() {
    local -n _stk="$1"
    local _out_var="$2"
    local _n=${#_stk[@]}

    if [[ -n "$_out_var" ]]; then
        printf -v "$_out_var" '%d' "$_n"
    else
        printf '%d\n' "$_n"
    fi
}

# stack_is_empty <stack_name>
stack_is_empty() {
    local -n _stk="$1"
    (( ${#_stk[@]} == 0 ))
}

# stack_clear <stack_name>
stack_clear() {
    local -n _stk="$1"
    _stk=()
}

# stack_print <stack_name>
stack_print() {
    local -n _stk="$1"
    local _n=${#_stk[@]}
    local _i

    if (( _n == 0 )); then
        echo "(empty stack)"
        return 0
    fi

    for (( _i=0; _i<_n; _i++ )); do
        if (( _i == _n-1 )); then
            printf '%s  <-- top\n' "${_stk[_i]}"
        else
            printf '%s\n' "${_stk[_i]}"
        fi
    done
}

# ---------------------------------------------------------------------
# Method 1: push/pop arrays BY REFERENCE (name-based)
# ---------------------------------------------------------------------

# stack_push_ref <stack_name> <array_var_name>
# Pushes the NAME of an existing array/assoc array as the element.
stack_push_ref() {
    local -n _stk="$1"
    _stk+=("$2")
}

# stack_pop_ref <stack_name> <out_var_for_name>
# Pops a stored name into out_var; bind with `declare -n x="$out_var"`.
stack_pop_ref() {
    local -n _stk="$1"
    local _n=${#_stk[@]}

    if (( _n == 0 )); then
        echo "stack_pop_ref: stack '$1' is empty" >&2
        return 1
    fi

    local _name="${_stk[_n-1]}"
    unset '_stk[_n-1]'
    _stk=("${_stk[@]}")
    printf -v "$2" '%s' "$_name"
}

# ---------------------------------------------------------------------
# Method 2: push/pop arrays SERIALIZED (self-contained copy)
# ---------------------------------------------------------------------

# stack_push_array <stack_name> <indexed_array_var_name>
# Flattens the array's values into one string and pushes it.
stack_push_array() {
    local -n _stk="$1"
    local -n _arr="$2"
    local _IFS_OLD="$IFS"
    local IFS="$_STACK_SEP"
    _stk+=("${_arr[*]}")
    IFS="$_IFS_OLD"
}

# stack_pop_array <stack_name> <out_array_var_name>
# Pops the top element and reconstructs it into out_array_var_name.
stack_pop_array() {
    local -n _stk="$1"
    local -n _out="$2"
    local _n=${#_stk[@]}

    if (( _n == 0 )); then
        echo "stack_pop_array: stack '$1' is empty" >&2
        return 1
    fi

    local _serialized="${_stk[_n-1]}"
    unset '_stk[_n-1]'
    _stk=("${_stk[@]}")

    local IFS="$_STACK_SEP"
    read -ra _out <<< "$_serialized"
}

# stack_push_assoc <stack_name> <assoc_array_var_name>
# Flattens key=value pairs of an associative array into one string.
stack_push_assoc() {
    local -n _stk="$1"
    local -n _arr="$2"
    local _out="" _k

    for _k in "${!_arr[@]}"; do
        _out+="${_k}=${_arr[$_k]}${_STACK_SEP}"
    done
    _stk+=("$_out")
}

# stack_pop_assoc <stack_name> <out_assoc_array_var_name>
# Pops and reconstructs an associative array. out_assoc_array_var_name
# must already be declared with `declare -A` before calling.
stack_pop_assoc() {
    local -n _stk="$1"
    local -n _out="$2"
    local _n=${#_stk[@]}

    if (( _n == 0 )); then
        echo "stack_pop_assoc: stack '$1' is empty" >&2
        return 1
    fi

    local _serialized="${_stk[_n-1]}"
    unset '_stk[_n-1]'
    _stk=("${_stk[@]}")

    local IFS="$_STACK_SEP"
    local -a _pairs
    read -ra _pairs <<< "$_serialized"

    local _pair
    for _pair in "${_pairs[@]}"; do
        [[ -z "$_pair" ]] && continue
        _out["${_pair%%=*}"]="${_pair#*=}"
    done
}

# --- Self-test / demo (only runs if script is executed directly) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Scalars ==="
    stack_init s
    stack_push s "one" "two" "three"
    stack_print s
    stack_pop s v
    echo "popped: $v"

    echo
    echo "=== Indexed array, by reference ==="
    fruits=("apple" "banana" "cherry")
    stack_init s
    stack_push_ref s fruits
    stack_pop_ref s name
    declare -n ref="$name"
    echo "name=$name contents=${ref[@]}"

    echo
    echo "=== Indexed array, serialized (self-contained) ==="
    nums=(10 20 "30 with space")
    stack_init s
    stack_push_array s nums
    declare -a restored
    stack_pop_array s restored
    echo "restored=${restored[@]} count=${#restored[@]}"

    echo
    echo "=== Associative array, serialized ==="
    declare -A person=( [name]="Xvolks was here" [city]="Nievroz" )
    stack_init s
    stack_push_assoc s person
    declare -A restored_person
    stack_pop_assoc s restored_person
    for k in "${!restored_person[@]}"; do
        echo "  $k = ${restored_person[$k]}"
    done
fi
