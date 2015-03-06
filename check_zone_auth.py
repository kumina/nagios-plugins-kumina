#!/usr/bin/env python

import argparse
import dns.message
import dns.query
import dns.rcode
import dns.rdatatype
import dns.resolver
import random
import socket
import sys
import time

# Some exceptions that might be thrown during the run of this script
class NotAuthAnswerException(Exception):
    pass

class AddressFamilyNotSupportedException(Exception):
    pass

class NoAnswerException(Exception):
    pass

class AddressFamilyUnknownException(Exception):
    pass

# Functions that exit the program with the correct exit-codes
def ok(msg):
    print "ZONE %s OK: %s" % (zone_name, msg)
    sys.exit(0)

def critical(msg):
    print "ZONE %s CRITICAL: %s" % (zone_name, msg)
    sys.exit(1)

def warning(msg):
    print "ZONE %s WARNING: %s" % (zone_name, msg)
    sys.exit(2)

def unknown(msg):
    print "ZONE %s UNKNOWN: %s" % (zone_name, msg)
    sys.exit(3)

def sanitize_name(name):
    # Take the name and append a '.' at the end if there isn't any
    if name[-1] == '.':
        return name
    else:
        return '%s.' % name

def IP_version(address):
    # Return the address family
    try:
        v4 = socket.inet_pton(socket.AF_INET,address)
        return 4
    except:
        try:
            v6 = socket.inet_pton(socket.AF_INET6,address)
            return 6
        except:
            raise AddressFamilyUnknownException(address)

def get_addresses(name):
    # Use the system resolver to get address info
    global ip6
    global ip4
    ret = []
    try:
        if ip4:
            ret += [str(x) for x in dns.resolver.query(name, 'A',
                raise_on_no_answer=False).rrset]
    except:
        pass

    try:
        if ip6:
            ret += [str(x) for x in dns.resolver.query(name, 'AAAA',
                raise_on_no_answer=False).rrset]
    except:
        pass

    return ret

def do_query(qmsg, address, timeout=5, tries=5,
        raise_on_bad_address_family=False):
    global ip4
    global ip6
    if not ip6 and not ip4:
        raise Exception('There is no address family available')

    ip_version = IP_version(address)
    if ip_version == 4 and not ip4:
        if raise_on_bad_address_family:
            raise AddressFamilyNotSupportedException
        return False
    if ip_version == 6 and not ip6:
        if raise_on_bad_address_family:
            raise AddressFamilyNotSupportedException
        return False

    for attempt in range(tries):
        try:
            ans = dns.query.udp(qmsg, address, timeout=timeout)
            if debug or verbose:
                if verbose:
                    print 'Got reply from %s' % (address)
                else:
                    print 'Got answer from %s: \n%s' % (address, ans)
            return ans
        except socket.error as error_msg:
            # If the error is "[Errno 101] Network is unreachable", there is no
            # ip_version connectivity, disable it for the rest of the run
            if str(error_msg) == '[Errno 101] Network is unreachable':
                # TODO use eval() for this
                if ip_version == 4:
                    if debug or verbose:
                        print 'Disabeling IPv4'
                    ip4 = False
                if ip_version == 6:
                    if debug or verbose:
                        print 'Disabeling IPv6'
                    ip6 = False
                if raise_on_bad_address_family:
                    raise AddressFamilyNotSupportedException
                else:
                    return False
            else:
                raise
        except dns.exception.Timeout:
            if attempt == tries:
                raise
            time.sleep(1)

def get_reply_type(msg):
    # Returns the reply type of the message. Code and return values taken from ldns
    if not isinstance(msg, dns.message.Message):
        return 'UNKNOWN'

    if msg.rcode == dns.rcode.NXDOMAIN:
        return 'NXDOMAIN'

    if not len(msg.answer) and not len(msg.additional) and len(msg.authority) == 1:
        if msg.authority[0].rdtype == dns.rdatatype.SOA:
            return 'NODATA'

    if not len(msg.answer) and len(msg.authority):
        for auth_rrset in msg.authority:
            if auth_rrset.rdtype == dns.rdatatype.NS:
                return 'REFERRAL'

    # A little sketchy, but if the message is nothing of the above,
    # we'll label it as an answer
    return 'ANSWER'

def get_delegation():
    # This function iterates from the root to the final authoritative
    # nameservers using (where possible) the glue it gets.

    # let's have the root-servers as initial glue :)
    refs = {
        'A.ROOT-SERVERS.NET.': ['198.41.0.4', '2001:503:BA3E::2:30'],
        'B.ROOT-SERVERS.NET.': ['192.228.79.201'],
        'C.ROOT-SERVERS.NET.': ['192.33.4.12'],
        'D.ROOT-SERVERS.NET.': ['199.7.91.13', '2001:500:2D::D'],
        'E.ROOT-SERVERS.NET.': ['192.203.230.10'],
        'F.ROOT-SERVERS.NET.': ['192.5.5.241', '2001:500:2F::F'],
        'G.ROOT-SERVERS.NET.': ['192.112.36.4'],
        'H.ROOT-SERVERS.NET.': ['128.63.2.53', '2001:500:1::803F:235'],
        'I.ROOT-SERVERS.NET.': ['192.36.148.17', '2001:7FE::53'],
        'J.ROOT-SERVERS.NET.': ['192.58.128.30', '2001:503:C27::2:30'],
        'K.ROOT-SERVERS.NET.': ['193.0.14.129', '2001:7FD::1'],
        'L.ROOT-SERVERS.NET.': ['199.7.83.42', '2001:500:3::42'],
        'M.ROOT-SERVERS.NET.': ['202.12.27.33', '2001:DC3::35']
    }

    qmsg = dns.message.make_query(zone_name, dns.rdatatype.SOA)
    qmsg.flags = 0 # Remove the QR flag

    if debug or verbose:
        print 'Starting to iterate to get the delegation'

    while True:
        ans_pkt = None
        ref_list = random.sample(refs, len(refs))

        for ref in ref_list:
            if refs[ref] == []:
                # No referral additional data was sent, do a forward lookup
                # using the system resolver
                refs[ref] = get_addresses(ref)
            for addr in refs[ref]:
                if debug or verbose:
                    print 'Selected %s(%s) for query' % (ref, addr)
                ans_pkt = do_query(qmsg, addr, timeout=3, tries=2)
                if ans_pkt:
                    break
            if ans_pkt:
                break

        # Check if the answer-packet is
        # a referral, an answer or NODATA
        reply_type = get_reply_type(ans_pkt)
        if debug or verbose:
            print 'Got a %s reply' % reply_type
        if reply_type == 'REFERRAL':
            # We got a referral from the upstream nameserver
            final_ref = False
            refs = {}
            for rrset in ans_pkt.authority:
                if rrset.rdtype == dns.rdatatype.NS:
                    for ns in rrset:
                        refs[str(ns)] = []
                    if str(rrset.name) == zone_name:
                        if debug or verbose:
                            print '- This is the final referral'
                        final_ref = True
            for rrset in ans_pkt.additional:
                # hopefully we got some glue :)
                if rrset.rdtype == dns.rdatatype.AAAA or rrset.rdtype == dns.rdatatype.A:
                    for glue in rrset:
                        refs[str(rrset.name)].append(str(glue))
            if debug or verbose:
                print 'Got the following referrals:\n%s' % refs

            if final_ref:
                for ref in refs:
                    if refs[ref] == []:
                        refs[ref] = get_addresses(ref)
                return refs

            if len(refs):
                # Go to the next iteration
                continue
            else:
                unknown('Got a referral without glue')

        elif reply_type == 'ANSWER':
            # we reached the correct nameserver. This happens when the
            # nameserver for example.com is also authoritative for
            # sub.example.com and .com has send us a referral to example.com
            # So return the refs from the 'previous' iteration
            return refs

        elif reply_type == 'NODATA':
            # zonename is most-likely not a zone
            return {}

def is_same(items, field=False):
    # Returns true if all items are the same
    return all(x == items[0] for x in items)

def check_delegation(data, from_upstream, expected_ns_list=None):
    # Various checks to see if the delegation is correct
    name_list = []
    addr_list = []
    soa_rec_list = []
    soa_serial_list = []
    soa_ns_list = []
    ns_rec_list = []

    # Fill the lists with all the data we need to compare them later on
    for nameserver in data:
        for addr in data[nameserver]:
            name_list.append(nameserver)
            addr_list.append(addr)

            for answer in data[nameserver][addr]['SOA'].answer:
                if answer.rdtype == dns.rdatatype.SOA:
                    if not str(answer.name) == zone_name:
                        critical("Name on SOA record returned by %s on %s is not the zone name (%s vs %s)" % (nameserver, addr, answer.name, zone_name))
                    soa_rec_list.append(answer)
                    soa_serial_list.append(answer.to_text().split(' ')[6])
                    soa_ns_list.append(answer.to_text().split(' ')[4])

            for answer in data[nameserver][addr]['NS'].answer:
                if answer.rdtype == dns.rdatatype.NS:
                    if not str(answer.name) == zone_name:
                        critical("Name on NS record returned by %s on %s is not the zone name (%s vs %s)" % (nameserver, addr, answer.name, zone_name))
                    ns_recs = sorted([ns.split(' ')[4] for ns in [rdata for rdata in answer.to_text().split("\n")]])
                    ns_rec_list.append(ns_recs)
                    if expected_ns_list:
                        if ns_recs != sorted(expected_ns_list):
                            critical('Got unexpected NS records, expected %s, got %s from %s at %s'
                                % (','.join(sorted(expected_ns_list)),
                                    ','.join(sorted(ns_recs)), nameserver, addr))

            ns_dict = {}
            for addition in data[nameserver][addr]['NS'].additional:
                if str(addition.name) not in ns_dict:
                    ns_dict[str(addition.name)] = []

                for addition_address in [rdata.split(' ')[4] for rdata in
                addition.to_text().split('\n')]:
                    ns_dict[str(addition.name)].append(addition_address)

            if sorted(from_upstream) != sorted(ns_dict):
                if nameserver in from_upstream:
                    # querying ns.foobar.nl for glue in foobar.nl is unneccessary
                else:
                    warning('Addresses of nameservers on %s(%s) don\'t match upstream glue (%s vs %s)'
                        % (nameserver, addr, from_upstream, ns_dict))

    if not is_same(soa_serial_list):
        warning('serials in SOA don\'t match. Got %s' % ', '.join(['%s (%s): %s'
            % (name_list[i], addr_list[i], soa_serial_list[i]) for i in
            range(len(name_list))]))

    if not is_same(soa_ns_list):
        warning('primary nameservers in SOA don\'t match. Got %s' % ', '.join(['%s (%s): %s'
            % (name_list[i], addr_list[i], soa_ns_list[i]) for i in
            range(len(name_list))]))

    if not is_same(ns_rec_list):
        warning('Mis-matched NS records. Got %s' % ', '.join(['%s (%s): %s'
            % (name_list[i], addr_list[i], ns_rec_list[i]) for i in
                range(len(name_list))]))

    # If we're here, we got the correct nameservers.
    ok('got %s nameservers, SOA serial %s' % (len(ns_rec_list), soa_serial_list[0]))

def get_auth_data(rdtype, address):
    msg = dns.message.make_query(zone_name, eval('dns.rdatatype.%s' % rdtype))
    msg.flags = 0

    ret = do_query(msg, address, raise_on_bad_address_family=True)

    if 'AA' not in dns.flags.to_text(ret.flags):
        raise NotAuthAnswerException([rdtype, address])

    if get_reply_type(ret) != 'ANSWER':
        raise NoAnswerException([rdtype, address])

    return ret

def get_info_from_nameservers(refs):
    ret_data = {}

    for ns in refs:
        ret_data[ns] = {}
        for address in refs[ns]:
            if IP_version(address) == 4 and not ip4:
                continue
            if IP_version(address) == 6 and not ip6:
                continue

            if debug or verbose:
                print 'Getting SOA and NS info from %s on %s' % (ns, address)

            ret_data[ns][address] = {}
            try:
                ret_data[ns][address]['SOA'] = get_auth_data('SOA', address)
                ret_data[ns][address]['NS'] = get_auth_data('NS', address)
            except NotAuthAnswerException as e:
                critical('Got non-AA answer for %s from %s(%s)' % (e[0][0], ns,
                    address))
            except NoAnswerException as e:
                unknown('No %s records returned from %s(%s)' % (e[0], ns,
                    address))
            except AddressFamilyNotSupportedException:
                # Remove this entry from the dict, as we can never get the data.
                del ret_data[ns][address]
                continue

        if ret_data[ns] == {}:
            del ret_data[ns]

    return ret_data

parser = argparse.ArgumentParser(description='Check for delegation and zone-consistancy')
parser.add_argument('zone', help='Zone to check', metavar='ZONE')
parser.add_argument('-6', action='store_true', dest='ip6_only')
parser.add_argument('-4', action='store_true', dest='ip4_only')
parser.add_argument('--nameservers', '-n', help='A comma-separated list of expected nameservers')
parser.add_argument('--verbose', '-v', help='Be a little verbose',
        action='store_true')
parser.add_argument('--debug', '-d', help='Output debugging information',
        action='store_true')
args = parser.parse_args()

zone_name = sanitize_name(args.zone)
debug = args.debug
verbose = args.verbose

if args.ip4_only and args.ip6_only:
    unknown("Please use either -4, -6 or none, not both")

ip4 = True
ip6 = True

if args.ip4_only:
    ip6 = False
if args.ip6_only:
    ip4 = False

if args.nameservers:
    expected = [ sanitize_name(x) for x in args.nameservers.split(',') ]
else:
    expected = False

from_upstream = get_delegation()
if len(from_upstream):
    if len(from_upstream) == 1:
        # Only one auth is delegated... that is not the right way
        warning('only one authoritative nameserver from upstream: %s' % from_upstream.keys())
    # We got referrals
    if expected:
        if not sorted(from_upstream.keys()) == sorted(expected):
            critical('Got unexpected nameservers from upstream: expected %s, got %s'
                    % (', '.join(sorted(expected)), ', '.join(from_upstream.keys())))

    data = get_info_from_nameservers(from_upstream)
    check_delegation(data, from_upstream, expected)

else:
    unknown("No nameservers found, is %s a zone?" % zone_name)

# TODO
# - Write tests
# - TCP fallback + EDNS buffers
# - DNSSEC support
