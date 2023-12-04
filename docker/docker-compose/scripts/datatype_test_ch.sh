#!/bin/bash -ex

DATADIR=/tmp/types_data_ch

# startup
sudo rm -Rf $DATADIR/data
mkdir -p $DATADIR/data
docker start clickhouse-server || docker run -d --name clickhouse-server --ulimit nofile=262144:262144 clickhouse/clickhouse-server
sleep 3

CH()
{
    docker exec clickhouse-server clickhouse client -q "$1"
}

# fix config to produce compact format
if ! [ -f $DATADIR/config.xml ] ; then
    docker cp clickhouse-server:/etc/clickhouse-server/config.xml $DATADIR/
    sed -i 's%<clickhouse>%<clickhouse> <merge_tree> <min_bytes_for_wide_part>0</min_bytes_for_wide_part> </merge_tree>%' $DATADIR/config.xml
    docker cp $DATADIR/config.xml clickhouse-server:/etc/clickhouse-server/config.xml 
    docker restart clickhouse-server
    sleep 3
fi

# cleanup
CH "drop database itay;" || true

# settings
CH "SELECT * FROM system.merge_tree_settings where name like '%wide%';"
CH "SELECT * system.merge_tree_settings　WHERE name LIKE '%granularity%';"

# create
CH "create database itay;"

CH "CREATE TABLE itay.complex_types (map1 Map(String, String) CODEC(NONE), arr1 Array(String) CODEC(NONE)) ENGINE = MergeTree order by tuple();"
CH "INSERT INTO itay.complex_types VALUES ({'a_key1': 'a_val1', 'a_key2longer':'a_val2longer'}, ['a_aaa', 'a_bbbb', 'a_ccccc', 'a_dddddd' ]), ({'b_key1': 'b_val1', 'b_key2longer':'b_val2longer', 'b_key3':'b_val3'}, ['b_aaa', 'b_bbbb', 'b_ccccc', 'b_dddddd', 'b_eeeeeee']);"

docker cp clickhouse-server:/var/lib/clickhouse/data/itay/complex_types/all_1_1_0 $DATADIR/data
ls -lR $DATADIR/data
