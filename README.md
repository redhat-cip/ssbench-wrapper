ssbench wrapper script
======================

This script ease some ssbench use cases such as:
 * ssbench installation
 * standalone workers start (to spread workers on many hosts)
 * help jenkins integration
 * start a ramp up benchmark

wrapper installation
--------------------

The installation command will setup a python virtualenv and install
a specific ssbench tag. 

 ubuntu@client3:~/ssbench-wrapper$ sudo aptitude install `cat requirements.txt`
 ubuntu@client3:~/ssbench-wrapper$ pwd
 /home/ubuntu/ssbench-wrapper
 ubuntu@client3:~/ssbench-wrapper$ WORKSPACE=/home/ubuntu/ CHECKOUTDIR=ssbench-wrapper \
                                   bin/wrapper -m install

Deploy worker
-------------

One of the major problems when benchmarking is to be limitated by workers'host performances (CPU, network bandwidth) so it is convenient to have a way to spread client load through many hosts. ssbench use a message queue protocol to control and retrieve results from workers.
In this example we will start workers on one host but whether you have other hosts to start additional workers use the '-i' option to specify ssbench master IP. The wrapper script will deploy as many worker as CPU in the local host.

 ubuntu@client3:~/ssbench-wrapper$ WORKSPACE=/home/ubuntu/ CHECKOUTDIR=ssbench-wrapper bin/wrapper -m spawn_workers
 ubuntu@client3:~/ssbench-wrapper$ ps ax | grep ssbench-worker
 20012 pts/0    Sl     0:00 /home/ubuntu/ssbench-venv/bin/python bin/ssbench-worker --zmq-host 10.43.0.108 1081
 20020 pts/0    Sl     0:00 /home/ubuntu/ssbench-venv/bin/python bin/ssbench-worker --zmq-host 10.43.0.108 1082

As soon as the ssbench-master will start and open the message queue bus all workers will declare itself and will automaticaly used for the benchmark.

Run benchmark
-------------

The ssbench wrapper come with predefined scenarios. Those scenario files defined the following swift usage:

Basic scenarios (operations on 1KB object):
 pcreate : a PUT only operations benchmark
 pread : a READ only operation benchmark
 pupdate : a POST only operation benchmark
 pdelete : a DELETE only operation benchmark
More complex scenario:
 webserver : a typical usage of swift as webserser content backend
 dropbox : a typical usage of swift for a dropbox like usage
 backup : a typical usage of swift as backup server

 ubuntu@client3:~/ssbench-wrapper$ WORKSPACE=/home/ubuntu/ CHECKOUTDIR=ssbench-wrapper TENANT=demo USERNAME=demo PASSWORD=wxcvbn   KEYSTONE_ENDPOINT=http://10.43.0.54:5000/v2.0 SCENARIOS="pcreate" bin/wrapper -m bench -c 5

The wrapper script parsed the outputed result from ssbench to some CSV files:
 ubuntu@client3:~$ ls -al /home/ubuntu/*.csv
 -rw-rw-r-- 1 ubuntu ubuntu 19 May  6 09:15 /home/ubuntu/pcreate-create-ops-details.csv
 -rw-rw-r-- 1 ubuntu ubuntu 23 May  6 09:15 /home/ubuntu/pcreate-ops.csv
 -rw-rw-r-- 1 ubuntu ubuntu 19 May  6 09:15 /home/ubuntu/pcreate-total-ops-details.csv

The outputed report is saved in text format in /home/ubuntu/temp/pcreate.report. This report give results for a fixed amount of operations and a fixed client concurrency (here 5)

After the run ssbench will clean the swift account used for performing the benchmark.

Run a ramp up benchmark
-----------------------

With the benchmark mode you can't figure out if the value you provide as client concurrency is accurate or not. The idea behind the ramp up benchmark is to increase the client concurrency step by step at each benchmark run to find the cluster limit.
The default concurrency limit of a worker is 256 so you need to remind this value according to the worker amount you have started.
The ramp up benchmark will use the rampup scenario file which is a balanced mix of CRUD operations.

WORKSPACE=/home/ubuntu/ CHECKOUTDIR=ssbench-wrapper TENANT=demo USERNAME=demo PASSWORD=wxcvbn
KEYSTONE_ENDPOINT=http://10.43.0.54:5000/v2.0 bin/wrapper -m rampup -o 1000
...
Last run we got : 180 ops/s on swift with usage of 2 workers
Values (op/s) for previous runs are : 69 96 122 188 180
We just found cluster limit to 188 ops/s
Result details can be found in /tmp/csvrampup/1367834508.csv

The above result shows that we have performed five benchmark runs and had the best results for the fourth run at 188 op/s. The wrapper script will continue to increase the concurrency value until it find a lower op/s value than the previous one.

The details for all runs are saved in a CSV file. You see below that we had the best performance with a client concurrency value of 8.

 ubuntu@client3:~/ssbench-wrapper$ ubuntu@client3:~/ssbench-wrapper$ cat /tmp/csvrampup/1367834508.csv
 stage,workers,concurrency,ops
 1,2,2,69
 2,2,4,96
 3,2,6,122
 4,2,8,188
 5,2,10,180

Jenkins integration
-------------------

As said above the wrapper script parses outputed benchmark results to CSV file to ease plotting. For instance for the benchmark run in this guide we got three files which contains :

 # Operations by seconds for this use case by kind of operation
 ubuntu@client3:~$ cat pcreate-ops.csv 
 total,create
 91.9,91.9
 
 # For each kind of objects size (here the scenario just defines one)
 # the total latency to perform all kind of REST requests.
 ubuntu@client3:~$ cat pcreate-total-ops-details.csv 
 Small object
 0.053
 
 # For each kind of objects size (here the scenario just defines one)
 # the total latency to perform the specific PUT REST request.
 ubuntu@client3:~$ cat pcreate-create-ops-details.csv
 Small object
 0.053

By using the plot plugin of jenkins (https://wiki.jenkins-ci.org/display/JENKINS/Plot+Plugin) you will be able to compare performance results  between a defined amount of previous runs, letting you detect performance degradations/improvements. 

The following shows the wrapper integration in a jenkin's job:
 cd ssbench-wrapper
 CHECKOUTDIR=ssbench-wrapper bin/wrapper -m install
 CHECKOUTDIR=ssbench-wrapper TENANT=ssbench USERNAME=ssbench PASSWORD=secret KEYSTONE_ENDPOINT=http://10.68.0.150:5000/v2.0 bin/wrapper -m   clean_swift
 CHECKOUTDIR=ssbench-wrapper bin/wrapper -m kill_workers
 CHECKOUTDIR=ssbench-wrapper bin/wrapper -m spawn_workers
 CHECKOUTDIR=ssbench-wrapper TENANT=ssbench USERNAME=ssbench PASSWORD=secret KEYSTONE_ENDPOINT=http://10.68.0.150:5000/v2.0 SCENARIOS="pread"  bin/wrapper -m bench -c 16
