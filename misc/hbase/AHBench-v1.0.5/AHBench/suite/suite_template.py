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

# All test suites MUST define its own DEFAULTS properties.
# The properties priority order is here (left is prior to right):
#   command line > config file > suite
#
# Command Line Properties:
#       Load from run_suite commandline, like run_suite -p target=5000
#
# Config File Properties:
#       Load from ahbench-config.properties
#
# Suite Properties:
#       Load from ahben
#
# You can use prop() to pop a property from framework to run a command
#

DEFAULTS = {
}


# All test suites MUST define an suite entry method
# Put the test workflow in suite() method
def suite():
    pass


####################################
#
#  Command interface for test suites.
#  * DO NOT COPY THIS AREA *
####################################

def prop(name, default=None):
    """
    Get a property from framework

    :param name: property name
    :param default default value
    :return: Load value from properties, got default when not present
    """
    pass


def load(table, *args, **kwargs):
    """
    Load data into table
    This is an dumb interface, it'll be replaced dynamically at runtime
    :param kwargs:
        For stress:
            threads     Threads count for loading
                        default:
                            ahbench.table.load.threads or
                            ahbench.test.threads
            tps         Target transaction per seconds. Limit the load speed
                        default:
                            ahbench.table.load.tps
            test_name   Specify the loading procedure's name to save the result
        For data model:
            records     Record(row) count for table (in str)
                        default:
                            ahbench.table.records
            columns     Columns count for testing (in str)
                        default:
                            ahbench.table.columns
            key_length  Key length for test table (in str)
                        default:
                            ahbench.table.keylen
            value_length    Value length for test table (in str)
                        default:
                            ahbench.table.valuelen
    :return: None
    """
    pass


def test(table, test_name, workload, *args, **kwargs):
    """
    Run workload for table with test_name
    This is an dumb interface, it'll be replaced dynamically at runtime
    :param table:
    :param test_name: test_name for save the result
    :param workload: workload type, stay in workloads/*
    :param args:
    :param kwargs:
        For stress:
            threads     Threads for testing (in str)
                        default:
                            ahbench.test.threads
            operations  total operations in stress test
                        default:
                            ahbench.test.operations
            target_ops  OPS limit for testing (in str)
                        default:
                            No default properties
            run_time    Run time in seconds for testing (in str)
                        default:
                            ahbench.test.runtime
            scan_rows   Scanned rows in scan stress type (in str)
                        default:
                            No default properties
            batch_rows  Batched rows in batch stress type, both read in write (in str)
                        default:
                            No default properties
            dist_type   distribution type in stress test, like zipfian/uniform and so on
                        default:
                            No default properties
            read_all    whether read all data from table, 'true' or 'false'
                        default:
                            ahbench.test.readall
        For data model:
            records     Record(row) count for testing stress (in str)
                        default:
                            ahbench.test.records
                            or ahbench.table.records
            columns     Columns count for testing (in str)
                        default:
                            ahbench.test.columns
                            or ahbench.table.columns
            key_length  Key length for test table (in str)
                        default:
                            ahbench.table.keylen
            value_length    Value length for test table (in str)
                        default:
                            ahbench.table.valuelen
    :return: None
    """
    pass


def create(table, *args, **kwargs):
    """
    Create table.
    This is an dumb interface, it'll be replaced dynamically at runtime
    :param table:
    :param kwargs:
        compression  Compression algorithm for table
                     default:
                        ahbench.table.compression
        encoding     Encoding algorithm for table
                     default:
                        ahbench.table.encoding
        regions      Regions count algorithm for table (in string)
                     default:
                        ahbench.table.regions
        key_length   Key length for test table (in string)
                     default:
                        ahbench.table.keylen
    :return: None
    """
    pass


def compact(table, *args, **kwargs):
    """
    Major compacting table, and wait a while
    This is an dumb interface, it'll be replaced dynamically at runtime
    :param table:
    :param args:
    :param kwargs:
        flush_wait:     Time for waiting flush, in seconds (in string)
                        default:
                            ahbench.test.flush.wait
        compact_wait:   Time for waiting compaction, in seconds (in string)
                        default:
                            ahbench.test.compact.wait
    :return:
    """
    pass


def aggregate_result(result_name, *test_names):
    """
    Aggregate multiple test results into one csv file
    This is an dumb interface, it'll be replaced dynamically at runtime
    :param result_name: result_name to save
    :param test_names: test_names to aggregate
    :return: None
    """
    pass