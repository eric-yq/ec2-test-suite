#!/usr/bin/env python2.7
#
# Copyright Alibaba Group Holding Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from suite_template import prop, aggregate_result, create, test, load, compact

DEFAULTS = {
    'ahbench.table.name.for.read': 'ahbenchtest-read',
    'ahbench.table.name.for.write': 'ahbenchtest-write',
    'ahbench.table.records': '2000000000',
    'ahbench.table.regions': '200',
    'ahbench.table.keylen': '19',
    'ahbench.table.columns': '20',
    'ahbench.table.valuelen': '20',

    'ahbench.table.load.tps': '40000',    # Loading too fast may lead to files not fully compacted

    'ahbench.test.flush.wait': '180',
    'ahbench.test.compact.wait': '24000',

    'ahbench.test.runtime': '1200',
    'ahbench.test.spike.read.ops': '5000',
    'ahbench.test.spike.scan.ops': '5000',
    'ahbench.test.spike.write.ops': '50000',
    'ahbench.test.spike.batchwrite.ops': '2000',
    'ahbench.test.columns': '1',
    'ahbench.test.threads': '200',

    'ahbench.default_suite.test.read.records': '2000000',
}


def suite():
    table_for_read = prop('ahbench.table.name.for.read')
    table_for_write = prop('ahbench.table.name.for.write')
    test_read_records = prop('ahbench.default_suite.test.read.records')
    test_write_records = prop('ahbench.table.records')
    threads_for_single = prop('ahbench.test.threads')
    threads_for_mutli = str(int(threads_for_single) / 2)
    skip_load = prop('ahbench.skipload')
    run_time = prop('ahbench.default_suite.runtime')

    if (not skip_load) or not int(skip_load):
        create(table_for_read)
        load(table_for_read)
        compact(table_for_read)

    # 3. Write tests
    create(table_for_write)
    test(table_for_write, 'throughput_single_write', 'singlewrite',
         run_time=run_time, threads=threads_for_single,
         records=test_write_records)
    create(table_for_write)
    test(table_for_write, 'spike_single_write', 'singlewrite',
         run_time=run_time, threads=threads_for_single,
         target_ops=prop('ahbench.test.spike.write.ops'),
         records=test_write_records)

    # 4. Batch write tests
    create(table_for_write)
    test(table_for_write, 'throughput_batch_write', 'batchwrite',
         run_time=run_time, threads=threads_for_mutli,
         records=test_write_records)
    create(table_for_write)
    test(table_for_write, 'spike_batch_write', 'batchwrite',
         run_time=run_time, threads=threads_for_mutli,
         target_ops=prop('ahbench.test.spike.batchwrite.ops'),
         records=test_write_records)
    
    # 1. Read tests
#     test(table_for_read, 'warm_up_throughput_single_read', 'singleread',
#          run_time=run_time, threads=threads_for_single,
#          records=test_read_records)
    test(table_for_read, 'throughput_single_read', 'singleread',
         run_time=run_time, threads=threads_for_single,
         records=test_read_records)
#     test(table_for_read, 'warm_up_spike_single_read', 'singleread',
#          run_time=run_time, threads=threads_for_single,
#          target_ops=prop('ahbench.test.spike.read.ops'),
#          records=test_read_records)
    test(table_for_read, 'spike_single_read', 'singleread',
         run_time=run_time, threads=threads_for_single,
         target_ops=prop('ahbench.test.spike.read.ops'),
         records=test_read_records)
    
    # 2. Scan tests
#     test(table_for_read, 'warm_up_throughput_scan', 'scan',
#          run_time=run_time, threads=threads_for_mutli,
#          records=test_read_records)
    test(table_for_read, 'throughput_scan', 'scan',
         run_time=run_time, threads=threads_for_mutli,
         records=test_read_records)
#     test(table_for_read, 'warm_up_spike_scan', 'scan',
#          run_time=run_time, threads=threads_for_mutli,
#          target_ops=prop('ahbench.test.spike.scan.ops'),
#          records=test_read_records)
    test(table_for_read, 'spike_scan', 'scan',
         run_time=run_time, threads=threads_for_mutli,
         target_ops=prop('ahbench.test.spike.scan.ops'),
         records=test_read_records)


    # 5. Aggregate results
    aggregate_result('throughput', 'throughput_single_read', 'throughput_scan', 'throughput_single_write',
                     'throughput_batch_write')
    aggregate_result('spike_latency', 'spike_single_read', 'spike_scan', 'spike_single_write',
                     'spike_batch_write')
