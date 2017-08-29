# Munin-redshift-plugins

Bash munin plugins for monitoring an AWS Redshift database.

To make use of this plugins, you should first make sure you have the right configuration. 

## Installation & Configuration

You should create a munin plugin configuration with these variables an put them in
`/etc/munin/plugin-conf.d/munin-node`: 

```
[redshift*]
env.redshift_host <hostname>
env.redshift_port <port>
env.redshift_user <user>
env.redshift_pass <pass>
env.redshift_db <db>
```

Then checkout the project (somewhere)

```bash
# checkout the project (can be anywhere)
cd /usr/share/munin/plugins
git clone https://github.com/level23/munin-redshift-plugins.git
```

## Redshift Commit Queue

To make use of the commit queue plugin, simply create a simlink in the plugins directory for the munin node.

The output will be a graph which displays the average cmmit queue time (in seconds), the average commit time and the
average commit queue size. We will gather the data from the last 5 minutes. 

```bash
# Symlink the plugin in the munin-plugins dir:
ln -s /usr/share/munin/plugins/munin-redshift-plugins/redshift_commit_queue.sh redshift_commit_queue

# Test it like this (config):
munin-run redshift_commit_queue config 

# Then run it like this (should display a value)
munin-run redshift_commit_queue

# Restart the munin-node (if everything is ok)
service munin-node restart
```

## Redshift Disk-based queries.

The disk-based queries plugin is a little harder to set up. The query to collect the data is quite heavy, and 
therefor we do not execute this query every 5 minutes. 

We have build in a "cron" mode, which can be used to collect the data. Munin will ony use this "fetched" 
data.

To setup this plugin, first create a cronjob which collects the data. For example in `/etc/crontab`:
```
# Collect redshift disk-based queries (every hour)
0   *   *   *   *   root    munin-run redshift_disk_queries cron
```

Then, just install the script as a normal script:
```bash
# Symlink the plugin in the munin-plugins dir:
ln -s /usr/share/munin/plugins/munin-redshift-plugins/redshift_disk_queries.sh redshift_disk_queries

# Test it like this (config):
munin-run redshift_disk_queries config

# ONLY FIRST RUN, Fetch the data (note, has no output, takes some time!):
munin-run redshift_disk_queries cron 

# Then run the plugin (should output a value)
munin-run redshift_disk_queries

# Restart the munin-node (if everything is ok)
service munin-node restart
```