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

import os
import subprocess
import sys
import time


def load_util_env():
    util_path = os.path.join(os.path.dirname(sys.argv[0]), '..', 'bin', 'util')
    try:
        out_bytes = subprocess.check_output(["source %s && env" % util_path], shell=True)
        util_env = {}
        for line in out_bytes.splitlines():
            arr = line.split("=")
            key = arr[0]
            value = '='.join(arr[1:])
            util_env[key] = value
        return util_env
    except subprocess.CalledProcessError as e:
        sys.stderr.write(e.output)
        sys.exit(e.returncode)


UTIL_ENV = load_util_env()


def green_print(*args): _wrap_colour('\033[32m', sys.stdout, *args)


def red_print(*args): _wrap_colour('\033[31m', sys.stderr, *args)


def print_properties(props):
    """
    :type prop dict
    :param prop:
    :return:
    """
    sortedKey = [k for k in props]
    sortedKey.sort()
    for s in ['%s=%s' % (k, props[k]) for k in sortedKey]:
        print s


def load_properties(filename):
    """
    Load properties from file, change the properties to a str dictionary
    :param filename: The file path where to load properties
    :return: A dictionary with properties key/value pair
    """
    properties = {}
    with open(filename, 'r') as fp:
        for line in fp.readlines():
            val_line = _filter_comments_front_only(line)
            if not val_line:
                continue
            kv = line.strip().split('=', 1)
            if len(kv) < 2:
                raise ValueError("Invalid line in %s : %s", filename, line)
            properties[kv[0].strip()] = kv[1].strip()
    return properties


def find_any(*args):
    """
    :param args: list of object, left arg is prior to right one
    :return: first object not null
    """
    for obj in args:
        if obj is not None:
            return obj


def chain_map(obj, *methods):
    """
    :param obj: Source object for mapping
    :param methods: Mapping methods chain
    :return: None if obj is none, otherwise method(obj)
    """
    ret = obj
    for method in methods:
        if ret is None:
            return None
        ret = method(ret)
    return ret


def make_properties(arg_list):
    """
    make a str list like: 'a=b', 'c=d' to a properties dict, often used in command line parse
    :param arg_list: str list to make a properties dict
    :return: property dictionary
    """
    ret = {}
    for s in arg_list:
        arr = s.split('=', 1)
        key = arr[0].strip()
        value = arr[1].strip()
        ret[key] = value
    return ret


def merge_properties(*args):
    """
    :param args: list of properties dictionary, left arg is prior to right one
    :return: merged_dictionary
    """
    for i in range(0, len(args)):
        if type(args[i]) != dict:
            raise ValueError("Only support merge dictionary properties")
    ret = {}
    for dic in args:
        for k in dic:
            if (not ret.get(k)) and dic.get(k):
                ret[k] = dic.get(k)
    return ret


def sleep_for(secs, reason):
    """
    Sleep secs seconds
    :param secs: sleep time in seconds
    :return: None
    """
    now = 0
    while now < secs:
        time.sleep(1)
        now += 1
        sys.stdout.write('\r \033[5m Sleep %s/%s seconds \033[0m | For: %s' % (now, secs, reason))
        sys.stdout.flush()
    print


def _filter_comments_front_only(line):
    if line.strip().startswith('#'):
        return ''
    else:
        return line.strip()


def _filter_comments(line):
    if not line:
        return line.split('#', 1)[0]
    else:
        return ''


def _wrap_colour(colour, where, *args):
    for a in args:
        print >> where, colour + '{}'.format(a) + '\033[0m'


if __name__ == '__main__':
    d1 = {'a': 'a1', 'b': 'b1'}
    d2 = {'a': 'a2', 'c': 'c2'}
    print merge_properties(d1, d2)
    print find_any(0, 5, 10, None)
    print chain_map(None, int)
    print chain_map('5332', int, str, int, lambda x: x < 5000)
