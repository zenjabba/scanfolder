#!/bin/bash
# /path/scanfolder/scanfolder.sh -s tv/10s -c /mnt/unionfs/ -t tv -u PAS_URL:PORT/XXXX -o plex -z '/path to plex db/' -w 10 -r zendrive -a zd-tv2 
#-w = second to wait between sends to autoscan
#-r = RCLONE mount, like zendrive or zd_storage
#-a = the folder name at the base of the mount: zd-movies,zd-tv1,zd-tv2,zd-tv3
#-d = integer for number of days
#-h = integer for number of hours
#-l = path to autoscan.db /your/path/
# do not use both -d & -h
while getopts s:c:t:u:o:z:w:r:a:d:h: option; do 
    case "${option}" in
        s) SOURCE_FOLDER=${OPTARG};;
        c) CONTAINER_FOLDER=${OPTARG};;
        t) TRIGGER=${OPTARG};;
        u) URL=${OPTARG};;
        o) DOCKERNAME=${OPTARG};;
        z) PLEXDB=${OPTARG};;
        w) WAIT=${OPTARG};;
        r) RCLONEMOUNT=${OPTARG};;
        a) ZDTD=${OPTARG};;
        d) DAYS=${OPTARG};;
        h) HOURS=${OPTARG};;
               
     esac
done

get_files ()
{
  case $TRIGGER in
          movie)
                  depth=2
                  ;;
          tv|television|series)
                  depth=3
                  ;;
           music)
                  depth=3
                  ;;
          '')
                  echo "Media type parameter is empty"
                  exit;
                  ;;
          *)
                  echo "Media type specified unknown"
                  exit;
                  ;;
  esac
  unset MAXAGE
  if [ ! -z "${DAYS}" ] && [ ! -z "${HOURS}" ]; then 
     echo "Please no not use DAYS & HOURS together, you filthy animal";
  fi
  if [ ! -z "${DAYS}" ] && [ -z "${HOURS}" ]; then
    IFS=$'\n' 
    filelist=($(rclone lsf --files-only --absolute --max-age "${DAYS}d" --max-depth "$depth" --format pt --separator "|" "$RCLONEMOUNT:$ZDTD/$SOURCE_FOLDER"))
    unset IFS
    MAXAGE=1
  fi
  if [ -z "${DAYS}" ] && [ ! -z "${HOURS}" ]; then
    IFS=$'\n' 
    filelist=($(rclone lsf --files-only --absolute --max-age "${HOURS}h" --max-depth "$depth" --format pt --separator "|" "$RCLONEMOUNT:$ZDTD/$SOURCE_FOLDER"))
    unset IFS
    MAXAGE=1
  fi
  if [ -z ${MAXAGE+x} ]; then
     IFS=$'\n' 
    filelist=($(rclone lsf --files-only --absolute --max-depth "$depth" --format pt --separator "|" "$RCLONEMOUNT:$ZDTD/$SOURCE_FOLDER"))
    unset IFS
  fi
  file_list=()
  for i in "${filelist[@]}"
  do
     FOO=$(basename "${i}")     
     FOO="$(echo -e "${FOO}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
     FOO=${#FOO}  
     F2=1
     if [ "$FOO" -gt "$F2" ]; then        
        file_list+=("${CONTAINER_FOLDER}${SOURCE_FOLDER}${i}")
     fi
  done
}

get_db_items ()
{ 
         cmd="select p.file,p.created_at from media_items m inner join media_parts p on m.id=p.media_item_id WHERE p.file LIKE '%$SOURCE_FOLDER/%'"
         if [ ! -z "$PLEXDB" ]
         then
             plex="${PLEXDB}com.plexapp.plugins.library.db"
         else
             plex="/opt/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
         fi
         db_list=()
         IFS=$'\n'
         fqry=(`sqlite3 "$plex" "$cmd"`)
         unset IFS
         for f in "${fqry[@]}"; do
           db_list+=("${f}")
         done
}

process_PAS ()
{
   curl -d "eventType=Manual&filepath=${1}" $URL > /dev/null
}

get_files
[[ ${#file_list[@]} -eq 0 ]] && { echo "No new media to process"; exit; }
get_db_items
IFS=$'\n'
mapfile -t missing_files < <( comm -13 --nocheck-order <(printf '%s\n' "${db_list[@]}" | LC_ALL=C sort) <(printf '%s\n' "${file_list[@]}" | LC_ALL=C sort) )
unset IFS
declare -a farray
for i in "${missing_files[@]}"; 
do
  f=("$(cut -d '|' -f1 <<< "$i")");
  f=${f//[$'\t\r\n']}
  if [ $TRIGGER == "music" ]; then
    echo "skip"
    farray+=("${f}")
  else
    farray+=("$(dirname "${f}")")
  fi
done
IFS=$'\n'
readarray -t uniq < <(printf '%s\n' "${farray[@]}" | sort -u)
unset IFS
c=1
for i2 in "${uniq[@]}"; 
do 
  g=${i2//[$'\t\r\n']}
  if [ ! -z "$g" ]; then
     if [ "${g}" != "${CONTAINER_FOLDER}${SOURCE_FOLDER}" ]; then
           process_PAS "${g}";
           c=$[$c +1]        
     fi
  fi
done
echo "${c} files processed" 
