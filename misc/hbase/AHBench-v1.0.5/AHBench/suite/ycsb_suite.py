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
    'ahbench.table.name': 'ahbenchtest-ycsb',
    'ahbench.table.regions': '100',
    'ahbench.table.records': '100000000',
    'ahbench.table.keylen': '19',
    'ahbench.table.columns': '10',
    'ahbench.table.valuelen': '100',
    'ahbench.table.load.threads': '40',

    'ahbench.test.runtime': '3600',
    'ahbench.test.operations': '2000000000',
    'ahbench.test.flush.wait': '180',
    'ahbench.test.compact.wait': '7200',

    # Skip all loading phase
    # 0 means false, 1 means true
    'ahbench.skipload': '0',

    # Do flush and compaction after loading
    # 0 means false, 1 means true
    'ahbench.ycsb-test.compaction.after.load': '0',

    # Do loading before every ycsb workload
    # If false, the loading phase will be done before all tests
    # 0 means false, 1 means true
    'ahbench.ycsb-test.create.table.for.each.run': '1',
}


def suite():
    table = prop('ahbench.table.name')
    skip_load = bool(int(prop('ahbench.skipload')))
    create_table_before_each_run = bool(int(prop('ahbench.ycsb-test.create.table.for.each.run')))
    compaction_after_load = bool(int(prop('ahbench.ycsb-test.compaction.after.load')))

    result_set = []
    if not create_table_before_each_run:
        create(table)
        if not skip_load:
            load(table, test_name='load')
            result_set.append('load')
            if compaction_after_load:
                compact(table)

    test_set = ['workloada', 'workloadb', 'workloadc', 'workloadd', 'workloade', 'workloadf']
    for testcase in test_set:
        if create_table_before_each_run:
            create(table)
            if not skip_load:
                load(table, test_name='load' + testcase)
                result_set.append('load' + testcase)
                if compaction_after_load:
                    compact(table)
        test(table, testcase, testcase)
        result_set.append(testcase)

    aggregate_result('ycsb_standard', *result_set)
