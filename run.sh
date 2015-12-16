#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

readonly DOMAINS=${DOMAINS}
readonly SOURCE_DATA_DIR=${SOURCE_DATA_DIR:-/data}
readonly DEST_DATA_DIR=${DEST_DATA_DIR:-/project}
readonly TESSERA_CONFIG="$DEST_DATA_DIR/config.json"

readonly PORT=${PORT:-80}
readonly CACHE_SIZE=${CACHE_SIZE:-10}
readonly SOURCE_CACHE_SIZE=${SOURCE_CACHE_SIZE:-10}

function serve_xray() {
    local mbtiles_file=$1
    exec bin/tessera.js "xray+mbtiles://$mbtiles_file" \
        --PORT $PORT \
        --cache-size $CACHE_SIZE \
        --source-cache-size $SOURCE_CACHE_SIZE
}

function find_first_mbtiles() {
    for mbtiles_file in "$SOURCE_DATA_DIR"/*.mbtiles; do
        echo "${mbtiles_file}"
        break
    done
}

function find_first_tm2() {
    for tm2project in "$SOURCE_DATA_DIR"/*.tm2/; do
        echo "${tm2project}"
        break
    done
}

function tessera_config_entry() {
    local tm2project=$1
    local serve_dir=${tm2project%.tm2}
    local serve_path=${serve_dir##*/}

    echo "\"/${serve_path}\": {\"source\":\"tmstyle://${tm2project}\", \"domains\": \"${DOMAINS}\"}," >> "$TESSERA_CONFIG"
    echo "Serving ${tm2project##*/} at $serve_path"
}

function create_tessera_config() {
    local mbtiles_file=$1
    rm -f "$TESSERA_CONFIG"
    echo '{' >> "$TESSERA_CONFIG"
    for tm2project in "$DEST_DATA_DIR"/*.tm2; do
        tessera_config_entry "${tm2project}"
    done

    ## Remove trailing comma unless adding vector tile source (below)
    #truncate --size=-2 "$TESSERA_CONFIG"
    # Always serve the vector tile source
    echo "\"/$(basename ${mbtiles_file%.*})\": \"mbtiles://${mbtiles_file}\"" >> "$TESSERA_CONFIG"

    echo '}' >> "$TESSERA_CONFIG"
}

function replace_sources() {
    mbtiles_file=$1
    local vectortiles_name=${mbtiles_file%.mbtiles}

    for project_dir in "$SOURCE_DATA_DIR"/*.tm2; do
        local project_name="${project_dir##*/}"
        local project_config_file="${project_dir%%/}/project.yml"

        # project config will be copied to new folder because we
        # modify the source configuration of the style and don't want
        # that to effect the original file
        dest_project_dir="${DEST_DATA_DIR%%/}/$project_name"
        local dest_project_config_file="${dest_project_dir%%/}/project.yml"
        cp -rf "$project_dir" "$dest_project_dir"

        # replace external vector tile sources with mbtiles source
        # this allows developing rapidyl with an external source and then use the
        # mbtiles for dependency free deployment
        echo "Associating $vectortiles_name with $project_name"
        replace_expr="s|source: \".*\"|source: \"mbtiles://$mbtiles_file\"|g"
        sed -e "$replace_expr" $project_config_file > $dest_project_config_file
    done
}

function serve_config() {
    exec bin/tessera.js -c "$TESSERA_CONFIG" \
        --PORT "$PORT" \
        --cache-size "$CACHE_SIZE" \
        --source-cache-size "$SOURCE_CACHE_SIZE"
}

function serve() {
    local mbtiles_file=$(find_first_mbtiles)
    local tm2project=$(find_first_tm2)
    if [ -f "$mbtiles_file" ]; then
        echo "Using $mbtiles_file as vector tile source"
        if [ -d "$tm2project" ]; then
            replace_sources "$mbtiles_file"
            create_tessera_config "$mbtiles_file"
            serve_config
        else
            echo "The mbtiles file is now served with X-Ray styles"
            serve_xray "$mbtiles_file"
        fi
    else
        # Serve empty config
        rm -f "$TESSERA_CONFIG"
        echo '{}' >> "$TESSERA_CONFIG"
        serve_config
    fi
}

serve
