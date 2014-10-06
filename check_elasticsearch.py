#!/usr/bin/env python

from nagioscheck import NagiosCheck, UsageError
from nagioscheck import PerformanceMetric, Status
import urllib2

try:
    import json
except ImportError:
    import simplejson as json

HEALTH = {'red':    0,
          'yellow': 1,
          'green':  2}

RED    = HEALTH['red']
YELLOW = HEALTH['yellow']
GREEN  = HEALTH['green']

HEALTH_MAP = {0: 'critical',
              1: 'warning',
              2: 'ok'}

SHARD_STATE = {'UNASSIGNED':   1,
               'INITIALIZING': 2,
               'STARTED':      3,
               'RELOCATING':   4}

class ESShard(object):
    def __init__(self, state):
        self.state = state

class ESIndex(object):
    def __init__(self, name, n_shards, n_replicas):
        self.name = name
        self.n_shards = n_shards
        self.n_replicas = n_replicas

class ESNode(object):
    def __init__(self, name=None, esid=None, attributes={}):
        self.esid = esid
        self.name = name
        self.attributes = attributes

class ElasticSearchCheck(NagiosCheck):
    version = '1.0.1'

    def __init__(self):
        NagiosCheck.__init__(self)

        self.health = HEALTH['green']

        self.add_option('f', 'failure-domain', 'failure_domain', "A "
                        "comma-separated list of ElasticSearch "
                        "attributes that make up your cluster's "
                        "failure domain[0].  This should be the same list "
                        "of attributes that ElasticSearch's location-"
                        "aware shard allocator has been configured "
                        "with.  If this option is supplied, additional "
                        "checks are carried out to ensure that primary "
                        "and replica shards are not stored in the same "
                        "failure domain. "
                        "[0]: http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/modules-cluster.html")

        self.add_option('H', 'host', 'host', "Hostname or network "
                        "address to probe.  The ElasticSearch API "
                        "should be listening here.  Defaults to "
                        "'localhost'.")

        self.add_option('m', 'master-nodes', 'master_nodes', "Issue a "
                        "warning if the number of master-eligible "
                        "nodes in the cluster drops below this "
                        "number.  By default, do not monitor the "
                        "number of nodes in the cluster.")

        self.add_option('p', 'port', 'port', "TCP port to probe.  "
                        "The ElasticSearch API should be listening "
                        "here.  Defaults to 9200.")

    def check(self, opts, args):
        host = opts.host or "localhost"
        port = int(opts.port or '9200')

        failure_domain = []
        if (isinstance(opts.failure_domain, str) and
            len(opts.failure_domain) > 0):
            failure_domain.extend(opts.failure_domain.split(","))

        if opts.master_nodes is not None:
            try:
                if int(opts.master_nodes) < 1:
                    raise ValueError("'master_nodes' must be greater "
                                     "than zero")
            except ValueError:
                raise UsageError("Argument to -m/--master-nodes must "
                                 "be a natural number")


        #
        # Data retrieval
        #

        # Request "about" info, so we can figure out the ES version,
        # to allow for version-specific API changes.
        es_about = get_json(r'http://%s:%d/' % (host, port))
        es_version = es_about['version']['number']

        # Request cluster 'health'.  /_cluster/health is like a tl;dr 
        # for /_cluster/state (see below).  There is very little useful 
        # information here.  We are primarily interested in ES' cluster 
        # 'health colour':  a little rating ES gives itself to describe 
        # how much pain it is in.
        es_health = get_json(r'http://%s:%d/_cluster/health' %
                             (host, port))

        self.health = HEALTH[es_health['status'].lower()]

        # Request cluster 'state'.  This be where all the meat at, yo.  
        # Here, we can see a list of all nodes, indexes, and shards in 
        # the cluster.  This response will also contain a map detailing 
        # where all shards are living at this point in time.
        #es_state = get_json(r'http://%s:%d/_cluster/state' %
        #                    (host, port))

        # Request a bunch of useful numbers that we export as perfdata.  
        # Details like the number of get, search, and indexing 
        # operations come from here.
        #es_stats = get_json(r'http://%s:%d/_nodes/_local/'
        #                     'stats?all=true' % (host, port))

        #myid = es_stats['nodes'].keys()[0]

        n_nodes  = es_health['number_of_nodes']
        n_dnodes = es_health['number_of_data_nodes']

        n_active_shards       = es_health['active_shards']
        n_relocating_shards   = es_health['relocating_shards']
        n_initialising_shards = es_health['initializing_shards']
        n_unassigned_shards   = es_health['unassigned_shards']
        n_shards = (n_active_shards + n_relocating_shards +
                    n_initialising_shards + n_unassigned_shards)

        # Add cluster-wide metrics first.  If you monitor all of your ES 
        # cluster nodes with this plugin, they should all report the 
        # same figures for these labels.  Not ideal, but 'tis better to 
        # graph this data multiple times than not graph it at all.
        metrics = [["cluster_nodes",                 n_nodes],
                   ["cluster_data_nodes",            n_dnodes],
                   ["cluster_active_shards",         n_active_shards],
                   ["cluster_relocating_shards",     n_relocating_shards],
                   ["cluster_initialising_shards",   n_initialising_shards],
                   ["cluster_unassigned_shards",     n_unassigned_shards],
                   ["cluster_total_shards",          n_shards]]

        #
        # Assertions
        #

        detail = [] # Collect error messages into this list

        msg = "Monitoring cluster '%s', status %s" % (es_health['cluster_name'],
              es_health['status'])

        # ES detected a problem that we did not.  This should never 
        # happen.  (If it does, you should work out what happened, then 
        # fix this code so that we can detect the problem if it happens 
        # again.)  Obviously, in this case, we cannot provide any useful 
        # output to the operator.
        raise Status(HEALTH_MAP[self.health],
                     (msg, None, "%s %s" % (msg, " ".join(detail))),
                      metrics)

def booleanise(b):
    """Normalise a 'stringified' Boolean to a proper Python Boolean.

    ElasticSearch has a habit of returning "true" and "false" in its 
    JSON responses when it should be returning `true` and `false`.  If 
    `b` looks like a stringified Boolean true, return True.  If `b` 
    looks like a stringified Boolean false, return False.

    Raise ValueError if we don't know what `b` is supposed to represent.

    """
    s = str(b)
    if s.lower() == "true":
        return True
    if s.lower() == "false":
        return False

    raise ValueError("I don't know how to coerce %r to a bool" % b)

def get_json(uri):
    try:
        f = urllib2.urlopen(uri)
    except urllib2.HTTPError, e:
        raise Status('unknown', ("API failure",
                                 None,
                                 "API failure:\n\n%s" % str(e)))
    except urllib2.URLError, e:
        # The server could be down; make this CRITICAL.
        raise Status('critical', (e.reason,))

    body = f.read()

    try:
        j = json.loads(body)
    except ValueError:
        raise Status('unknown', ("API returned nonsense",))

    return j

def version(version_string):
    """Accept a typical version string (ex: 1.0.1) and return a tuple
    of ints, allowing for reasonable comparison."""
    return tuple([int(i) for i in version_string.split('.')])

if __name__ == '__main__':
    ElasticSearchCheck().run()
