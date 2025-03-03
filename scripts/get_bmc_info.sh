#!/bin/bash
cd $(dirname "$0")

ipmitool lan print 1
echo
echo