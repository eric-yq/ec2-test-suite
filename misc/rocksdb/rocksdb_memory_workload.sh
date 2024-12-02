#!/bin/bash
## On Amazon Linux 2

# sudo su - root

PRINT_INFO(){
    echo "[Info] $(date +%Y%m%d.%H%M%S) : $1"
}

## Benchmark 流程
PN=$(dmidecode -s system-product-name | tr ' ' '_')
LOG_PATH="$HOME/RocksDB_Benchmark_memory_workload_$PN"
mkdir -p $LOG_PATH

## Cache Benchmark
TEST="Cache"
LOG_FILE="$LOG_PATH/$TEST.log"
PRINT_INFO "Start to peform $TEST Benchmark..."
sync; echo 3 > /proc/sys/vm/drop_caches 
./cache_bench -cache_size 10737418240 > $LOG_FILE 2>&1
PRINT_INFO "Complete to peform $TEST Benchmark."
# ./cache_bench -stress_cache_key

mkdir -p /mnt/db/ /data/users/rocksdb/

##################################################################################################
PRINT_INFO "Start to peform RocksDB In Memory Workload Performance Benchmarks"
## 内存工作负载
## 1. Point Query
## 1.1. 80K writes/sec
TEST="Point_Lookup_80K_WritePerSecond"
PRINT_INFO "Start to peform $TEST Benchmark..."
# Here is the command for filling up the DB:
ACTION="FillingUpDB"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=20 --keys_per_prefix=0 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --benchmarks=filluniquerandom --use_existing_db=0 --num=524288000 --threads=1 --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

# Here is the command for running readwhilewriting benchmark:
ACTION="ReadWhileWriting"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=20 --keys_per_prefix=0 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --duration=7200 --benchmarks=readwhilewriting --use_existing_db=1 --num=524288000 --threads=$(nproc)  --benchmark_write_rate_limit=81920 --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

PRINT_INFO "Complete to peform $TEST Benchmark."

## 1.2. 10K writes/sec
TEST="Point_Lookup_10K_WritePerSecond"
PRINT_INFO "Start to peform $TEST Benchmark..."
# Here is the command for filling up the DB:
ACTION="FillingUpDB"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=20 --keys_per_prefix=0 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/0_WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --benchmarks=filluniquerandom --use_existing_db=0 --num=524288000 --threads=1 --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

# Here is the command for running readwhilewriting benchmark:
ACTION="ReadWhileWriting"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=20 --keys_per_prefix=0 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/0_WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --duration=7200 --benchmarks=readwhilewriting --use_existing_db=1 --num=524288000 --threads=$(nproc)  --benchmark_write_rate_limit=10240 --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

PRINT_INFO "Complete to peform $TEST Benchmark."

## 2. Prefix Range Query
## 2.1. 80K writes/sec
TEST="Prefix_Range_Query_80K_WritePerSecond"
PRINT_INFO "Start to peform $TEST Benchmark..."
# Here is the command for filling up the DB:
ACTION="FillingUpDB"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=12 --keys_per_prefix=10 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --benchmarks=filluniquerandom --use_existing_db=0 --num=524288000 --threads=1  --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

# Here is the command for running readwhilewriting benchmark:
ACTION="ReadWhileWriting"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=12 --keys_per_prefix=10 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --duration=7200 --benchmarks=readwhilewriting --use_existing_db=1 --num=524288000 --threads=$(nproc)  --benchmark_write_rate_limit=81920 --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

## 2.2. 10K writes/sec
TEST="Prefix_Range_Query_10K_WritePerSecond"
PRINT_INFO "Start to peform $TEST Benchmark..."
# Here is the command for filling up the DB:
ACTION="FillingUpDB"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=12 --keys_per_prefix=10 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/0_WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --benchmarks=filluniquerandom --use_existing_db=0 --num=524288000 --threads=1  --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

# Here is the command for running readwhilewriting benchmark:
ACTION="ReadWhileWriting"
LOG_FILE="${LOG_PATH}/${TEST}_${ACTION}.log"
PRINT_INFO "  $ACTION....."
./db_bench --db=/mnt/db/rocksdb --num_levels=6 --key_size=20 --prefix_size=12 --keys_per_prefix=10 --value_size=100 --cache_size=17179869184 --cache_numshardbits=6 --compression_type=none --compression_ratio=1 --min_level_to_compress=-1 --disable_seek_compaction=1  --write_buffer_size=134217728 --max_write_buffer_number=2 --level0_file_num_compaction_trigger=8 --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --disable_wal=0 --wal_dir=/data/users/rocksdb/0_WAL_LOG --sync=0 --verify_checksum=1 --delete_obsolete_files_period_micros=314572800 --max_background_compactions=4 --max_background_flushes=0 --level0_slowdown_writes_trigger=16 --level0_stop_writes_trigger=24 --statistics=0 --stats_per_interval=0 --stats_interval=1048576 --histogram=0 --use_plain_table=1 --open_files=-1 --mmap_read=1 --mmap_write=0 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --duration=7200 --benchmarks=readwhilewriting --use_existing_db=1 --num=524288000 --threads=$(nproc)  --benchmark_write_rate_limit=10240 --allow_concurrent_memtable_write=false > $LOG_FILE 2>&1

PRINT_INFO "Complete to peform $TEST Benchmark."
PRINT_INFO "Complete to peform RocksDB In Memory Workload Performance Benchmarks"

cp /root/nohup.out ${LOG_PATH}/
tar czfP ${LOG_PATH}.tar.gz ${LOG_PATH}