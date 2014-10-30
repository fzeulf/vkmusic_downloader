# Vk music downloader

### Description
Simple perl script for search and download music from vk.com
Required active account in the vk system, credentials must be placed in the configfile.pm

I try to avoid of using any of external perl libraries, so you don't need to load any of them.
All you need is curl programm installed for your OS

### Setup
1. `git clone https://github.com/fzeulf/vkmusic_downloader`
2. `cd vkmusic_downloader`
3. `cp configfile.pm.example configfile.pm`
4. set in the configfile.pm these variables

    our $email = 'user@gmail.com'; 
    our $pass = 'password'; 
    our $download_dir = '/Users/fzeulf/Downloads/vk_downloads';
    our $ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.120 Safari/537.37';

* $email - registration email
* $pass - registration password
* $download_dir - full path to directory where music will be placed, script can create it if it doesn't exist
* $ua - browser user agent string, could be leaved as is

### Options and examples
    -s,--search name - search by given name
    -a,--artist - modificator for search by artist name
    -d,--debug - enable debug output
    -h,-?,--help - Print this help and exit

    Search by music name
    ./vkmusic_downloader.pl -s astrix
    Search by artist name
    ./vkmusic_downloader.pl -s astrix -a

Script write song list, and you could chose what download, by digits.
Multiple select is allowed through comma or dash.

### Change log
**Version 1.0**

- initial version
