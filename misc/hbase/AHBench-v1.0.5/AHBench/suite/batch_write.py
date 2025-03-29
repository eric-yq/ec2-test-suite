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

from suite_template import prop, create, test, aggregate_result

DEFAULTS = {
    'ahbench.table.name.for.write': 'ahbenchtest-write',
    'ahbench.table.records': '2000000000',
    'ahbench.table.columns': '1',
    'ahbench.table.regions': '200',
    'ahbench.table.keylen': '19',
    'ahbench.table.valuelen': '20',

    'ahbench.test.runtime': '1200',
    'ahbench.test.records': '2000000000',
    'ahbench.test.threads': '100',
}


def suite():
    table_for_write = prop('ahbench.table.name.for.write')
    if (not prop('ahbench.skipcreate')) or (not int(prop('ahbench.skipcreate'))):
        create(table_for_write)
    test(table_for_write, 'batch', 'batchwrite')
    aggregate_result('batch', 'batch')
