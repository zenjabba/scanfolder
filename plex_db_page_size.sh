#!/bin/bash
plexdb="/opt/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
plexdocker="plex"

N1=(`sqlite3 "$plexdb" "pragma page_size"`)
if [ "$N1" -eq "32768" ]; then 
  echo "page_size is already set to $N1" 
  exit; 
fi

docker stop "${plexdocker}"
cp "$plexdb" "$plexdb.original"
N2=(`sqlite3 "$plexdb" "DROP index 'index_title_sort_naturalsort'"`)
N3=(`sqlite3 "$plexdb" "DELETE from schema_migrations where version='20180501000000'"`)
sqlite3 "$plexdb" .dump > /tmp/dump.sql
rm "$plexdb"
N4=(`sqlite3 "$plexdb" "pragma page_size=32768; vacuum;"`)
N5=(`sqlite3 "$plexdb" "pragma page_size"`)
echo "$N5"
sqlite3 "$plexdb" < /tmp/dump.sql
docker start "${plexdocker}"
