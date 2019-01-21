#!/bin/bash
#set -u
set -e

. .methods/put/.index.conf

ignored=($IGNORE_FILES)
url=$URL
data=""

is_in() {

    local target=$1; shift
    local arr=("$@")
    local in=false

    for i in "${arr[@]}"; do
        if [[ $i == $target ]]; then
            in=true
            break
        fi
    done

    echo "$in"

    return 0
}

set_url() {
    # Sets the url according to path vars
    vars=$1; shift
    temp=$URL

    if [[ "${URL: -1}" == "/"  ]]; then
        echo "${URL}${vars}"

    else
        echo "${URL}/${vars}"

    fi
}

parse_data() {
    # Assembles a JSON-like string variable with
    # keys being the name of the files found in /_params
    # and the values being random lines of this files.

    local _data="{"
    local sep=""

    for file in $(ls .methods/put/_params); do

        if ! $(is_in "$file" "${ignored[@]}"); then
            local key=${file%.txt}
            local header=$(head -n 1 ".methods/put/_params/${file}")
            local pathvar=false

            if [[ $header == "__TYPE@PATHVAR__" ]]; then
                pathvar=true
                tail -n +2 ".methods/put/_params/${file}" > ".methods/put/_params/${file}.tmp"
                mv ".methods/put/_params/${file}.tmp" ".methods/put/_params/${file}"

                header=$(head -n 1 ".methods/put/_params/${file}")
            fi

            if [[ $header == "__TYPE@RANDOMNUMBER__" ]]; then
                local min=$(sed "2q;d" ".methods/put/_params/${file}")
                local max=$(sed "3q;d" ".methods/put/_params/${file}")
                local diff=$((max - min + 1))
                local value=$(( ($RANDOM % diff) + min ))

            else
                local n_of_lines=$(wc -l < ".methods/put/_params/${file}")
                local f_line=$(( ($RANDOM % n_of_lines) + 1  ))
                local value=$(sed "${f_line}q;d" ".methods/put/_params/${file}")
            fi

            if $pathvar; then
                url=$(set_url $value)

                sed -i "1s/^/__TYPE@PATHVAR__\n/" ".methods/put/_params/${file}"
                # same as sed -1 "1__TYPE@PATHVAR__" ".methods/put/_params/${file}"

            else
                _data="${_data}${sep} \"${key}\":\"${value}\""
                sep=","
            fi
        fi
    done

    data="$_data }"

    return 0
}

# TODO: Is this a bad solution?
parse_data

if [ -z $URL ]; then
    echo "No url provided."
    echo "Try ./manage seturl <urlname> or ./manage help for more information."
    exit 1

elif [ -z $VERBOSE ]; then
    echo "No verbose provided."
    echo "Try ./manage setverbose <option> or ./manage help for more information."
    exit 1

elif [ -z $HEADERS ]; then
    echo "No header provided."
    echo "Try ./manage setheader <headerlist> or ./manage help for more information."
    exit 1

fi

if [ $VERBOSE -eq 0 ]; then
    curl -X PUT "$url" -H "$HEADERS" -d "$data"

elif [ $VERBOSE -eq 1 ]; then
    curl -v -X PUT "$url" -H "$HEADERS" -d "$data"

else
    echo "ERROR: Unknown value for 'verbose' option."
    echo "The value $VERBOSE is not known for the option 'verbose', ABORTING."
    exit 1
fi

