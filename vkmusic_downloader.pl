#!/usr/bin/perl
# description: script for vk music download
# info: config must be in the configfile.pm 

use strict;
use warnings;
use utf8;
use open qw(:utf8 :std);
use configfile;
use Getopt::Long;
use Encode qw(decode encode);
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

my $VERSION = "1.0 (Sep 2014)";
my ($help, $curl_opts, $ch_curl, $curlout, $auth_loc, $user_id, $search, $search_artist);
my $debug = 0;
GetOptions ('h|help' => \$help, 'd|debug' => \$debug, 's|search=s' => \$search, 'a|artist' => \$search_artist) or exit;

print "\nWelcome to "; print BOLD RED "VKMusic downloader"; print " $VERSION\n";
if ($help) {
    print <<endOfTxt;

        usage: $0 [OPTIONS] 

        OPTIONS
            -s,--search name - search by given name
            -a,--artist - modificator for search by artist name
            -d,--debug - enable debug output
            -h,-?,--help - Print this help and exit

        EXAMPLES
            Search by music name
            $0 -s astrix
            Search by artist name
            $0 -s astrix -a

endOfTxt
    exit;
}

$ch_curl = `which curl`;
chomp ($ch_curl);
if ($debug) {
    $curl_opts = "-i -v";
} else {
    $curl_opts = "-s";
}

if (not $ch_curl) {
    print RED "Curl programm can not be found, install it please.\n" and exit;
}
if (not $email) {
    print RED "Define login email in the config file, please.\n" and exit;
}
if (not $pass) {
    print RED "Define password in the config file, please.\n" and exit;
}
if (($search_artist) && (not $search)) {
    print RED "-a could be used only with -s option.\n" and exit;
}

my %html_codes = ( # not all of them, but more popular
    "&amp;" => '&', "&#32;" => ' ', "&#33;" => '!', "&#34;" => '"', "&#35;" => '#', "&#36;" => '$',
    "&#37;" => '%', "&#38;" => '&', "&#39;" => "'", "&#40;" => '(', "&#41;" => ')', "&#42;" => '*',
    "&#43;" => '+', "&#44;" => ',', "&#45;" => '-', "&#46;" => '.', "&#47;" => '/', "&#123;" => '{',
    "&#124;" => '|', "&#125;" => '}', "&#126;" => '~', "&#178;" => '²',
);

my $cookie_fname = "cookie.vk";

print GREEN "Checking download dir:";
if (-d $download_dir) {
    print GREEN " OK\n";
} else {
    my @dirs_path = split (/\//, $download_dir); # i avoid of using File::Path::make_path because this function could has different name in different versions of perl
    my $full_path;
    foreach my $dir (@dirs_path) {
        $full_path .= "$dir/";
        if (not -d $full_path) {
            unless (mkdir "$full_path") {
                print RED " Can't create $full_path, check permissions, or create it by yourself\n" and exit;
            }
        }
    }
    print GREEN " Created $full_path\n";
}
print GREEN "Authorizaion:";
$curlout = `curl -i -c $cookie_fname -A "$ua" -X POST -d "email=$email" -d "pass=$pass" "https://login.vk.com/?act=login" 2>&1`;
_print_debug($curlout) if $debug;
if ($curlout =~ m/Location\:\s+(.+hash=.+)/) {
    $auth_loc = $1;
    $auth_loc =~ s/\r|\n//;
}
exit unless _print_ok_fail ($auth_loc, " OK", " Fail: check authorization data ($email:$pass), can't authorize with them");

print GREEN "Opening music:";
$curlout = `curl $curl_opts -b $cookie_fname -c $cookie_fname -A "$ua" "$auth_loc" 2>&1`;
$curlout = `curl -v -b $cookie_fname -A "$ua" "https://vk.com/feed" 2>&1`;
_print_debug($curlout) if $debug;
if ($curlout =~ m/id="head_music"\s+href="\/audios(\d+)/) {
    $user_id = $1;
    $user_id =~ s/\r|\n//;
}
exit unless _print_ok_fail ($user_id, " OK", " Fail: Can't parse vk.com main page, may be it was changed");

print GREEN "Loaded music list:\n";
if ($search) {
    $search =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
}
if ($search_artist) {
    $curlout = `curl -v -b $cookie_fname -A "$ua" -H "Accept-Language:en-US,en;q=0.8" -X POST -d "act=search&al=1&autocomplete=1&gid=0&id=$user_id&offset=0&performer=1&q=$search&sort=0" "https://vk.com/audio" 2>&1`;
} elsif ($search) {
    $curlout = `curl -v -b $cookie_fname -A "$ua" -H "Accept-Language:en-US,en;q=0.8" -X POST -d "act=search&al=1&autocomplete=1&gid=0&id=$user_id&offset=0&q=$search&sort=0" "https://vk.com/audio" 2>&1`;
} else {
    $curlout = `curl -v -b $cookie_fname -A "$ua" -H "Accept-Language:en-US,en;q=0.8" "https://vk.com/audios$user_id" 2>&1`;
}
_print_debug($curlout) if $debug;
my @music_html = split (/\n/, $curlout);
my (@music_base, $music_src, $artist, $name);
my $item = 1;
foreach my $string (@music_html) {
    $string = decode('cp1251', encode('utf8', $string));
    if ($string =~ m/<input\s+type="hidden"\s+id="audio_info\d+\_\d+"\s+value="([^\?]+)/) {
        $music_src = $1;
    }
    if ($music_src) {
        #$DB::single=1;
        if ($string =~ m/<a\s+href="\/search\?c\[q\]=.*\s+name:\s+\'(.+)\'.*<span\sclass="title">(?:<a[^\>]*)*([^\<]*).*/) {
            $artist = $1;
            $name = $2;
            $name =~ s/>//;
            foreach my $symbol (keys %html_codes) {
                $artist =~ s/$symbol/$html_codes{$symbol}/g;
                $name =~ s/$symbol/$html_codes{$symbol}/g;
            }
            my $str = sprintf ("[%d] %-20s - %-20s", $item, $artist, $name);
            print CYAN "$str\n";
            $music_base[$item] = ["$artist - $name", "$music_src"];
            $item++;
        }
    } else {
        $music_src = undef;
    }
}
exit unless _print_ok_fail ($user_id, "------------------------------------------------------------------------", "Fail: Can't parse vk.com main page, may be it was changed");

print GREEN "Select song number (multiple select through comma) [1]: ";
my $ch_input = 0;
my @selected;
until ($ch_input) {
    chomp(my $selected = <STDIN>);
    if (not $selected) {
        push (@selected, 1); 
        $ch_input = 1;
    } elsif ($selected eq "q") {
        exit;
    } elsif ($selected !~ m/(?:\d+)|(?:\d+\,\d+.+)/) {
        print RED "Define number i.e. 1 or numbers through comma i.e 1,2,3, or list 1-5, or print q for exit\n";
    } else {
        if ($selected =~ m/(\d+)-(\d+)/) {
            @selected = $1 .. $2;
        }
        else {
            @selected = split (/,/, join(',', $selected));
        }
        $ch_input = 1;
    }
}

print GREEN "Downloading:\n";
foreach my $music (@selected) {
    my $str = sprintf ("[%d] %-s", $music, ${$music_base[$music]}[0]);
    print CYAN "\t$str";
    system("curl $curl_opts -b $cookie_fname -A \"$ua\" \"${$music_base[$music]}[1]\" > \"$download_dir/${$music_base[$music]}[0].mp3\" 2>&1");
    my $file_chk = -f qq($download_dir/${$music_base[$music]}[0].mp3);
    _print_ok_fail ($file_chk, " OK", " Fail: Cant't download $!");
}

unlink $cookie_fname;

sub _print_ok_fail {
    my $selector = shift;
    my $good_phrase = shift;
    my $bad_phrase = shift;

    if ($selector) {
        my $str = sprintf ("%s", $good_phrase);
        print GREEN "$str\n";
        return 1;
    } else {
        my $str = sprintf ("%s", $bad_phrase);
        print RED "$str\n";
        return 0;
    }
}

sub _print_debug {
    my $curlout = shift;

    print YELLOW "\n" . "-" x 80 . "\n";
    print YELLOW "$curlout";
    print YELLOW "-" x 80 . "\n";
}
