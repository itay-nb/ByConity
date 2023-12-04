#!/bin/bash -ex

# startup
docker-compose -f docker-compose.essentials.yml -f docker-compose.simple.yml up -d
sleep 60

CH() {
    docker-compose -f docker-compose.essentials.yml -f docker-compose.simple.yml exec server-0 clickhouse client --port 52145  -q "$@"
}

# cleanup
CH "drop database itay;" || true
docker-compose -f docker-compose.essentials.yml -f docker-compose.simple.yml exec hdfs-namenode hdfs dfs -rm -r /user/clickhouse || true

# settings
CH "SELECT * FROM system.merge_tree_settings where name like '%wide%';"
CH "SELECT *　FROM system.merge_tree_settings　WHERE name LIKE '%granularity%';"

# create
CH "create database itay;"

# simple
CH "create table itay.simple (a UInt32) ENGINE=CnchMergeTree order by tuple();"
CH "insert into itay.simple values (1);"

# complex
#CH "CREATE TABLE itay.complex_types (key UInt16, map1 Map(UInt32, UInt64), arr1 Array(UInt8)) ENGINE = CnchMergeTree order by tuple();"
#CH "INSERT INTO itay.complex_types VALUES (1, {100: 101, 200:201, 300:301}, [64, 65, 66, 67, 68]);"
CH "CREATE TABLE itay.complex_types (map1 Map(String, String), arr1 Array(String)) ENGINE = CnchMergeTree order by tuple();"
CH "INSERT INTO itay.complex_types VALUES ({'a_key1': 'a_val1', 'a_key2longer':'a_val2longer'}, ['a_aaa', 'a_bbbb', 'a_ccccc', 'a_dddddd' ]), ({'b_key1': 'b_val1', 'b_key2longer':'b_val2longer', 'b_key3':'b_val3'}, ['b_aaa', 'b_bbbb', 'b_ccccc', 'b_dddddd', 'b_eeeeeee']);"

# show resulting files
docker-compose -f docker-compose.essentials.yml -f docker-compose.simple.yml exec hdfs-namenode hdfs dfs -ls -R /user/clickhouse/

# import part files
rm -Rf /tmp/types_data
docker-compose -f docker-compose.essentials.yml -f docker-compose.simple.yml exec hdfs-namenode rm -Rf /tmp/data
docker-compose -f docker-compose.essentials.yml -f docker-compose.simple.yml exec hdfs-namenode hdfs dfs -get /user/clickhouse /tmp/data
namenode=$(docker-compose -f docker-compose.essentials.yml -f docker-compose.simple.yml ps --quiet hdfs-namenode)
docker cp $namenode:/tmp/data /tmp/types_data

echo $0: Data file are in /tmp/types_data
echo "-----------------------------------------"
ls -lR /tmp/types_data
