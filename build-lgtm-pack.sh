#!/bin/bash

set -e

# https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

deploy_dir="$DIR/deploy"
mkdir -p "$deploy_dir"
echo "Using deploy directory $deploy_dir"

rev=$(git -C $DIR rev-parse HEAD)
echo "Building LGTM query packs for revision $rev."
for lang in cpp python csharp go javascript java
do
    if [ -d "$DIR/$lang" ]
    then
        echo "Building LGTM query pack for language $lang."
        temp_dir=$(mktemp -d -t lgtm-$lang-query-pack)
        
        # Include all queries, or
        #for ql in $(find "$DIR/$lang" -name "*.ql")
        # Queries specified in the selected suites, in this case all the default suites.
        suites=`if [ -d "$DIR/$lang/codeql-suites" ]; then echo -n $(find $DIR/$lang/codeql-suites -name '*-default.qls'); else echo -n ""; fi`
        if [ -z "$suites" ]; then echo "No suites available, skipping LGTM query pack for $lang"; continue; fi

        echo "Running test suite before building LGTM query pack for language $lang."
        if ! codeql test run --search-path $DIR $(find $DIR/$lang -type d -name test) > /dev/null 2>&1
        then 
            echo "Failing build of LGTM query pack for language $lang, not all tests passed."
            continue
        fi

        echo "Using suites: $suites"
        for ql in $(codeql resolve queries --search-path $DIR $suites)
        do 
            query_without_extension=${ql%.*}
            query_dir=$(dirname $ql)
            output_dir="$temp_dir${query_dir##*src}"
            mkdir -p $output_dir
            cp $query_without_extension.ql $output_dir
            [ -f $query_without_extension.qhelp ] && cp $query_without_extension.qhelp $output_dir
        done

        for qll in $(find "$DIR/$lang" -name "*.qll")
        do
            qll_dir=$(dirname $qll)
            output_dir="$temp_dir${qll_dir##*src}"
            cp $qll $output_dir
        done


        pushd $temp_dir >/dev/null 2>&1
        rm -f $deploy_dir/lgtm-$lang-query-pack-$rev.zip
        zip -9 -r $deploy_dir/lgtm-$lang-query-pack-$rev.zip * >/dev/null 2>&1 || echo "Skipping LGTM query pack for language $lang, no queries to include."
        popd  >/dev/null 2>&1

        rm -rf "$temp_dir"
    else
        echo "Skipping LGTM query pack for language $lang."
    fi
done
echo "Done"