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

my $VERSION = "1.0 (Dec 2014)";
my ($help, $curl_opts, $ch_curl, $curlout, $auth_loc, $user_id, $search, $search_artist, $all_user_music);
my $debug = 0;
GetOptions ('h|help' => \$help, 'd|debug' => \$debug, 's|search=s' => \$search, 'a|artist' => \$search_artist, 'u|usermusic' => \$all_user_music) or exit;

print "\nWelcome to "; print BOLD RED "VKMusic downloader"; print " $VERSION\n";
if ($help) {
    print <<endOfTxt;

        usage: $0 [OPTIONS] 

        OPTIONS
            -s,--search name - search by given name
            -a,--artist - modificator for search by artist name
            -d,--debug - enable debug output
            -u,--usermusic - show all user music
            -h,-?,--help - Print this help and exit

        EXAMPLES
            Search by music name
            $0 -s 'Candy Shop'
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
    "&quot;" => '"', "&amp;" => '&', "&#32;" => ' ', "&#33;" => '!', "&#34;" => '"', "&#35;" => '#', "&#36;" => '$',
    "&#37;" => '%', "&#38;" => '&', "&#39;" => "'", "&#40;" => '(', "&#41;" => ')', "&#42;" => '*',
    "&#43;" => '+', "&#44;" => ',', "&#45;" => '-', "&#46;" => '.', "&#47;" => '/', "&gt;" => '>', "&lt;" => '<', "&#123;" => '{',
    "&#124;" => '|', "&#125;" => '}', "&#126;" => '~', "&#178;" => '²', "&#953;" => 'ι', "&#9824;" => '♠', "&#9829;" => '♥',
    "&#9827;" => '♣', "&#9830;" => '♦',
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
} elsif ($all_user_music) {
    $curlout = `curl -v -b $cookie_fname -A "$ua" -H "Accept-Language:en-US,en;q=0.8" -X POST -d "act=load_audios_silent&al=1&gid=0&id=$user_id&please_dont_ddos=1" "https://vk.com/audio" 2>&1`;
} else {
    $curlout = `curl -v -b $cookie_fname -A "$ua" -H "Accept-Language:en-US,en;q=0.8" "https://vk.com/audios$user_id" 2>&1`;
}
_print_debug($curlout) if $debug;
my @music_html = split (/\n/, $curlout);
my (@music_base, $music_src, $artist, $name);
my $item = 1;
foreach my $string (@music_html) {
    $string = decode('cp1251', encode('utf8', $string));
    if (not $all_user_music) {
        if ($string =~ m/<input\s+type="hidden"\s+id="audio_info\d+\_\d+"\s+value="([^\?]+)/) {
            $music_src = $1;
        }
        if ($music_src) {
            if ($string =~ m/<a\s+href="\/search\?c\[q\]=.*\s+name:\s+\'(.+)\'.*<span\sclass="title">(.*)/) {
                $artist = $1;
                $name = _parser($2);
                foreach my $symbol (keys %html_codes) {
                    $artist =~ s/$symbol/$html_codes{$symbol}/g;
                    $name =~ s/$symbol/$html_codes{$symbol}/g;
                }
                if ($name =~ m/(.*[^\ ])\s+$/) {
                    $name = $1;
                }
                my $str = sprintf ("[%d] %-20s - %-20s", $item, $artist, $name);
                print CYAN "$str\n";
                $music_base[$item] = ["$artist - $name", "$music_src"];
                $item++;
            }
        } else {
            $music_src = undef;
        }
    } else {

    }
}
exit unless _print_ok_fail ($user_id, "------------------------------------------------------------------------", "Fail: Can't parse vk.com main page, may be it was changed");

print GREEN "Select song number (h for help) [1]: ";
my $ch_input = 0;
my @selected;
until ($ch_input) {
    chomp(my $selected = <STDIN>);
    if (not $selected) {
        push (@selected, 1); 
        $ch_input = 1;
    } elsif ($selected eq "q") {
        exit;
    } elsif (($selected eq "*")||($selected eq "all")) {
        @selected = 1 .. scalar(@music_base);
        $ch_input = 1;
    } elsif ($selected eq "h") {
        print "Define number i.e. 1 or numbers through comma i.e 1,2,3, or list 1-5, * / all - select all, q - exit\n";
    } elsif ($selected =~ m/(\d+)-(\d+)/) {
        @selected = $1 .. $2;
        $ch_input = 1;
    } elsif ($selected =~ m/\d+,\d+/) {
        @selected = split (/,/, join(',', $selected));
        $ch_input = 1;
    } elsif ($selected =~ m/\d+/) {
        push (@selected, $selected);
        $ch_input = 1;
    } else {
        print "Define number i.e. 1 or numbers through comma i.e 1,2,3, or list 1-5, * / all - select all, q - exit\n";
    }
}
my @ch_selected;
foreach my $selected (@selected) {
    push (@ch_selected, $selected) if $music_base[$selected];
}
if (scalar(@ch_selected) == 0) { 
    print RED "Nothing was selected\n" and exit;
} else {
    print GREEN "Downloading:\n";
}
my %replaced_sym = ('/' => '.', '\s+' => ' ', "'" => "");
#$DB::single=1;
foreach my $music (@ch_selected) {
    my $str = sprintf ("[%d] %-s", $music, ${$music_base[$music]}[0]);
    print CYAN "\t$str";
    my $fname = ${$music_base[$music]}[0];
    foreach my $symbol (keys %replaced_sym) {
        $fname =~ s/$symbol/$replaced_sym{$symbol}/g;
    }
    $fname .= ".mp3";
    system("curl $curl_opts -b $cookie_fname -A \"$ua\" \"${$music_base[$music]}[1]\" > \'$download_dir/$fname\' 2>&1");
    $fname =~ s/"/\"/g;
    my $file_chk = -f "$download_dir/$fname";
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

sub _parser {
    my $string = shift;
    my $name;
    #print MAGENTA "\n-$string-";
    if ($string =~ m/^(<span>.+)/) {
        #print "\nSPAN-$1-\n";
        $name = _tags_parser ("<", ">", "</span><span", $1);
    } elsif ($string =~ m/^<a[^>]*>(.+)/) {
        #print "\nA-$1-\n";
        $name = _tags_parser ("<", ">", "</a>", $1);
    } elsif ($string =~ m/([^\<]*)/) {
        $name = $1;
    } else {
        print RED "-$string-\n";
    }

    return $name;
}

sub _tags_parser {
    my $delim_open = shift;
    my $delim_close = shift;
    my $end = shift;
    my $string = shift;
    my ($text, $text_buf, $buf_enabled, $tag_start);

    my @end = split (//, $end);
    my @string = split (//, $string);
    my $end_iter = 0;
    foreach my $smb (@string) {
        if ($smb eq $delim_open) {
            $tag_start = 1;
        }
        if ($smb eq $end[$end_iter]) {
            unless ($text_buf) {
                $buf_enabled = 1;
            }
            if (not $tag_start) {
                $text_buf .= $smb;
            }
            $end_iter++;
        } elsif ($buf_enabled) {
            if (not $tag_start) {
                $text .= $text_buf;
            }
            $buf_enabled = 0;
            $text_buf = "";
            $end_iter = 0;
        }
        if ($end_iter == scalar(@end)) {
            last;
        }
        if ($tag_start) {
            if ("$smb" ne "$delim_close") {
                next;
            } else {
                $tag_start = 0;
                next;
            }
        }
        if (not $buf_enabled) {
            $text .= $smb;
        }
    }
    return $text;
}
