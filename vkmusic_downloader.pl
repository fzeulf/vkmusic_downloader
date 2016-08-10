#!/usr/bin/perl
##!/usr/bin/perl5.16
# written by fzeulf
# description: script for vk music download
# info: config must be in the configfile.pm 

use strict;
use warnings;
use utf8;
binmode STDOUT, ":utf8";
use threads;
use threads::shared;
use FindBin qw( $Bin );
use lib ("$Bin");
use Thread::Semaphore;
use open qw(:utf8 :std);
use configfile;
use Getopt::Long;
use Encode qw(decode encode);
binmode STDOUT, ':utf8';
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use constant DELIM_S => '-' x 80;
$| = 1;

my $VERSION = "1.5 (Aug 2016)";
my ($help, $curl_opts, $ch_curl, $curlout, $auth_loc, $user_id, $search, $search_artist, $all_user_music, $show_playlists);
my ($succ_op, $failed_op) :shared;
my $debug = 0;
$succ_op = 0;
$failed_op = 0;
my $sem = Thread::Semaphore->new($num_of_downloads - 1);
GetOptions ('h|help' => \$help, 'd|debug' => \$debug, 's|search=s' => \$search, 'a|artist' => \$search_artist, 'u|usertracks' => \$all_user_music, 'p|playlists' => \$show_playlists) or _print_help();

print "\nWelcome to "; print BOLD RED "VKMusic downloader"; print " $VERSION\n";
_print_help() if ($help);

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
if ($] == 5.018002) {
    print RED "Perl version 5.018002 has an issue with threading, use any other version of perl\n" and exit;
}

# https://en.wikipedia.org/wiki/List_of_Unicode_characters
my %html_codes = ( # not all of them, but more popular. NOTE: Some of them replaced by another symbols, due OS console restrictions
    "&quot;" => '"', "&amp;" => '&', "&#32;" => ' ', "&#33;" => '!', "&#34;" => '"', "&#35;" => '#', "&#36;" => '$',
    "&#37;" => '%', "&#38;" => '&', "&#39;" => ".", "&#40;" => '(', "&#41;" => ')', "&#42;" => '*',
    "&#43;" => '+', "&#44;" => ',', "&#45;" => '-', "&#46;" => '.', "&#47;" => '|', "&#92;" => "|", "&#092;" => "|",
    "&gt;" => '>', "&lt;" => '<', "&#123;" => '{',
    "&#124;" => '|', "&#125;" => '}', "&#126;" => '~', "&#178;" => '²', "&#953;" => 'ι', "&#9824;" => '♠', "&#9829;" => '♥',
    "&#9827;" => '♣', "&#9830;" => '♦', "&#9835;" => '♫', "&#9679;" => '●', "&#729;" => '˙', "&#3665;" => '๑', "&#1632;" => '٠', 
    "&#903;" => '·',
);

my $cookie_fname = "cookie.vk";

print GREEN "Checking download dir:";
if (-d $download_dir) {
    print GREEN " '$download_dir' OK\n";
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
#$DB::single=1;
$curlout = `curl -i -c $cookie_fname -A "$ua" "https://login.vk.com/?act=login" -H "origin: https://vk.com" -H "accept-encoding: gzip, deflate" -H "accept-language: en-US,en;q=0.8" -H "content-type: application/x-www-form-urlencoded" -H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" -H "cache-control: max-age=0" -H "cookie: remixdt=0; remixlang=0; remixseenads=2; remixlhk=bf2d1843e55161340b; remixflash=18.0.0; remixscreen_depth=24" --data "act=login&role=al_frame&expire=&captcha_sid=&captcha_key=&_origin=https"%"3A"%"2F"%"2Fvk.com&ip_h=ea277a92d28dda8c81&lg_h=570421fe6130338962&email=$email&pass=$pass" 2>&1`;
_print_debug($curlout) if $debug;
if ($curlout =~ m/Location\:\s+(.+hash=.+)/) {
    $auth_loc = $1;
    $auth_loc =~ s/\r|\n//;
	sleep 1;
}
exit unless _print_ok_fail ($auth_loc, " OK", " Fail: check authorization data ($email:$pass), can't authorize with them");

print GREEN "Opening music:";
for (my $i = 0; $i < 5; $i++) {
	$curlout = _cmd_timeout("curl $curl_opts -b $cookie_fname -c $cookie_fname -A \"$ua\" \"$auth_loc\" 2>&1");
	sleep 1 and next if $curlout eq 0;
	$curlout = _cmd_timeout("curl -v -b $cookie_fname -A \"$ua\" \"https://vk.com/feed\" 2>&1");
	sleep 1 and next if $curlout eq 0;
	_print_debug($curlout) if $debug;
	if ($curlout =~ m/id="head_music"\s+href="\/audios(\d+)/) {
		$user_id = $1;
		$user_id =~ s/\r|\n//;
		sleep 1;
		last;
	}
}
exit unless _print_ok_fail ($user_id, " OK", " Fail: Can't parse vk.com main page, may be it was changed");

print GREEN "Loading music list:\n";
if ($search) {
    $search =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
}
my $music_html_cmd = "";
if ($search_artist) {
    $music_html_cmd = "curl -v -b $cookie_fname -A \"$ua\" -H \"Accept-Language:en-US,en;q=0.8\" -X POST -d \"act=search&al=1&autocomplete=1&gid=0&id=$user_id&offset=0&performer=1&q=$search&sort=0\" \"https://vk.com/audio\" 2>&1";
} elsif ($search) {
    $music_html_cmd = "curl -v -b $cookie_fname -A \"$ua\" -H \"Accept-Language:en-US,en;q=0.8\" -X POST -d \"act=search&al=1&autocomplete=1&gid=0&id=$user_id&offset=0&q=$search&sort=0\" \"https://vk.com/audio\" 2>&1";
} elsif (($all_user_music)||($show_playlists)) {
    $music_html_cmd = "curl -s -b $cookie_fname -A \"$ua\" -H \"Accept-Language:en-US,en;q=0.8\" -X POST -d \"act=load_audios_silent&al=1&gid=0&id=$user_id&please_dont_ddos=1\" \"https://vk.com/audio\" 2>&1";
} else {
    $music_html_cmd = "curl -v -b $cookie_fname -A \"$ua\" -H \"Accept-Language:en-US,en;q=0.8\" \"https://vk.com/audios$user_id\" 2>&1";
}

for (my $i = 0; $i < 5; $i++) {
	$curlout = _cmd_timeout($music_html_cmd);
	sleep 1 and next if $curlout eq 0;
	if ($curlout =~ m/audios$user_id/) {
		sleep 1;
		last;
	}
}
_print_debug($curlout) if $debug;
my @music_html = split (/\n/, $curlout);
my (@music_base, $music_src, $artist, $name);
my $item = 1;
#$DB::single=1;
foreach my $string (@music_html) {
    $string = decode('cp1251', encode('utf8', $string));
    if ($all_user_music) {
        @music_base = _json_parser ($string);
        for (my $i = 1; $i <= $#music_base; $i++) {
            _print_music_string($i, $music_base[$i]{'artist'}, $music_base[$i]{'song_name'}, $music_base[$i]{'dur'}, 1);
        }
    } elsif ($show_playlists) {

    } else {
        if ($string =~ m/<input\s+type="hidden"\s+id="audio_info\S+"\s+value="([^\?]+)/) {
            $music_src = $1;
        }
        if ($music_src) {
            if ($string =~ m/<a\s+href="\/search\?c\[q\]=.*\s+name:\s+\'(.+)\'.*<span\sclass="title">(.*)/) {
                #print "->>$string\n\n";
                $artist = _convert_symbols($1);
                $name = _convert_symbols(_html_parser($2));
                if ($artist =~ m/^\s*(.+)\s*$/) {
                    $artist = $1;
                }
                if ($name =~ m/(.*[^\ ])\s+$/) {
                    $name = $1;
                }
                $music_base[$item] = {
                    'artist' => "$artist",
                    'song_name' => "$name", 
                    'src' => "$music_src"
                };
            }
            if ($string =~ m/<div\s+class="duration\s+fl_r">(.+)<\/div>/) {
                $music_base[$item]{'dur'} = "$1";
                _print_music_string($item, $artist, $name, $1, 1);
                $item++;
                $music_src = undef;
            }
        } 
    }
}
exit unless _print_ok_fail (scalar(@music_base), "\n". DELIM_S, "Fail: Can't parse vk.com audio page, may be it was changed");

print GREEN "Select song number (h for help) [1]: ";
my $ch_input = 0;
my @selected;
until ($ch_input) {
    chomp(my $selected = <STDIN>);
    if (not $selected) {
        push (@selected, 1); 
        $ch_input = 1;
    } elsif ($selected eq "q") {
        unlink $cookie_fname;
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
foreach my $music_num (@ch_selected) {
    my $fname = "$music_base[$music_num]{'artist'} - $music_base[$music_num]{'song_name'}";
    foreach my $symbol (keys %replaced_sym) {
        $fname =~ s/$symbol/$replaced_sym{$symbol}/g;
    }
    $fname .= ".mp3";
    my $thread = threads->create(\&_download_track, $music_num, $fname);
    $sem->down;
}

my $all_threads_done = 0;
until ($all_threads_done) {
    if (scalar (threads->list(threads::running)) == 0) {
        $all_threads_done = 1;
        $_->join() foreach (threads->list(threads::joinable));
    }
    select(undef, undef, undef, 0.500);
}
print GREEN DELIM_S . "\n";
print YELLOW "Downloaded: ";
print GREEN "$succ_op";
print YELLOW " / ";
print RED "$failed_op\n";

unlink $cookie_fname;

sub _cmd_timeout {
    my $cmd = shift;
    my $timeout = shift; # timeout in seconds
    $timeout = defined $timeout ? $timeout : 10;    

	my $output = "";
    eval {
        local $SIG{ALRM} = sub { die "timeout_alarm\n" };
        alarm $timeout;
        $output = `$cmd`;
        alarm 0;
    };
    if (defined($@)) {
        if ($@ eq "timeout_alarm\n") {
			_print_ok_fail (0, "", " Fail: '$cmd' not finished in $timeout sec. Output: '$@ $output'");
            return 0;
        }
    }
	return $output;
}

sub _download_track {
    my $music_num = shift;
    my $fname = shift;
    my $retval = 1;
    system("curl $curl_opts -b $cookie_fname -A \"$ua\" \"$music_base[$music_num]{'src'}\" > \'$download_dir/$fname\' 2>&1");
    _print_music_string($music_num, $music_base[$music_num]{'artist'}, $music_base[$music_num]{'song_name'}, $music_base[$music_num]{'dur'});
    $fname =~ s/"/\"/g;
    my $file_chk = -f "$download_dir/$fname";
    my $file_size = -s "$download_dir/$fname";
    if (($file_chk)&&($file_size != 0)) {
        $succ_op++;   
        _print_ok_fail ($file_size, " OK", " Fail: file has zero size");
    } else {
        if (not $file_chk) {
            _print_ok_fail ($file_chk, " OK", " Fail: Cant't download $!");
        } else {
            _print_ok_fail ($file_size, " OK", " Fail: file has zero size");
        }
        $failed_op++;
        $retval = 0;
    }
    $sem->up;
    return $retval;
}

sub _convert_symbols {
    my $string = shift;
    foreach my $symbol (keys %html_codes) {
        $string =~ s/$symbol/$html_codes{$symbol}/g;
    }
    return $string;
}

sub _print_help {
    print <<endOfTxt;

        usage: $0 [OPTIONS] 

        OPTIONS
            -s,--search name - search by given name
            -a,--artist - modificator for search by artist name
            -d,--debug - enable debug output
            -u,--usertracks - show all user tracks
            -p,--playlists - show all user playlists [not implemented yet]
            -h,-?,--help - Print this help and exit

        EXAMPLES
            Show first 50 user tracks:
            $0
            Show all user tracks:
            $0 -u
            Search by track name:
            $0 -s 'Candy Shop'
            Search by artist name:
            $0 -s astrix -a
            Show all user playlists
            $0 -p

endOfTxt
    exit;
}

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
    print YELLOW "\n" . "-" x 80 . "\n";
}

sub _print_music_string {
    my $item = shift;
    my $artist = shift;
    my $name = shift;
    my $duration = shift;
    my $new_line = shift;

    my $artist_pr = sprintf ("%-20s - ", $artist);
    my $name_pr = sprintf ("%-20s", $name);
    print CYAN "[$item] ";
    print WHITE "$artist_pr";
    print BRIGHT_BLUE "$name_pr";
    print CYAN " ($duration)";
    print "\n" if $new_line;

}

sub _html_parser {
    my $string = shift;
    my $name;
    _print_debug($string) if $debug;
    if (($string =~ m/([^\<]*)/) and ($string !~ m/<a class=/) and ($string !~ m/<span>/)) { # name without link
        _print_debug("NO TAG: $1") if $debug;
        $name = $1;
    } elsif ($string =~ m/(<span>.+)/) { # formatted by span tags name
        $name = _tags_parser ("<", ">", "</span><span", $1);
        _print_debug("SPAN: $1") if $debug;
    } elsif ($string =~ m/<a[^>]*>(.+)/) { # name is link
        $name = _tags_parser ("<", ">", "</a>", $1);
        _print_debug("A: $1") if $debug;
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

sub _json_parser {
    my $string = shift;
    my @string = split (//, $string);
    my ($block_start, @music_base, $param_start, $param, @block_params);
    my $music_num = 1;
    my $prev_smb = "";
    foreach my $smb (@string) {
        if (($smb eq "]")&&($prev_smb eq "]")) {
            last;
        }
        if (($smb eq "[")&&(not $param_start)&&(not $block_start)) {
            $block_start = 1;
        } elsif (($smb eq "]")&&(not $param_start)&&($block_start)) {
            my $artist = _convert_symbols($block_params[5]);
            my $song_name = _convert_symbols($block_params[6]);
            $music_base[$music_num] = {
                'artist' => "$artist",
                'song_name' => "$song_name", 
                'src' => "$block_params[2]",
                'dur' => "$block_params[4]",
                'plst' => $block_params[8],
            };
            $music_num++;
            $block_start = 0;
            @block_params = ();
			print "\rProcessed: $music_num";
        }
        if (($block_start)&&($smb eq "'")&&(not $param_start)) {
            $param_start = 1;
            next;
        } elsif (($block_start)&&($param_start)&&($smb eq "'")) {
            push (@block_params, $param);
            $param_start = 0;
            $param = "";
        }
        if (($block_start)&&($param_start)) {
            $param .= $smb;
        }
        $prev_smb = $smb;
    }
	print "\n";
    return @music_base;
}
