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

```
    our $email = 'user@gmail.com';
    our $pass = 'password';
    our $download_dir = '/Users/fzeulf/Downloads/vk_downloads';
    our $ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.120 Safari/537.37';
```
* $email - registration email
* $pass - registration password
* $download_dir - full path to directory where music will be placed, script can create it if it doesn't exist
* $ua - browser user agent string, could be leaved as is

### Options and examples
    -s,--search name - search by given name
    -a,--artist - modificator for search by artist name
    -d,--debug - enable debug output
    -u,--usermusic - show all user music
    -h,-?,--help - Print this help and exit

    Show first 50 user music:
    ./vkmusic_downloader.pl
    Show all user added music:
    ./vkmusic_downloader.pl -u
    Search by music name:
    ./vkmusic_downloader.pl -s 'Candy Shop'
    Search by artist name:
    ./vkmusic_downloader.pl -s astrix -a

Output will be like this:

```
[1] Astrix               - Beyond The Senses.   (7:45)
[2] Astrix               - Sex Style            (6:50)
[3] Astrix               - Antiwar (Red Means Distortion 2010) (7:36)
```

Where:

* **[1]** - consecutive number
* **Astrix** - artist name
* **Beyond The Senses.** - song name
* **(7:45)** - song duration

Then you could select any particular song or number of songs (by consecutive number) write and push enter:
- digits through comma (1,3,4,10)
- digits through dash (1-12)
- * or all for downloading whole list
- h for help.

### Notes

Was tested for:
- MAC OS X
- Windows (Cygwin + curl compilation from src)

### Change log
**Version 1.1**

- Show all user added music

**Version 1.0**

- Shows first 50 user songs
- Can search by music name or by artist name
- Can download any count of searched songs
