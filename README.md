# Vk music downloader
![image](https://raw.githubusercontent.com/fzeulf/vkmusic_downloader/master/executed.png)
### Description
Simple perl script for search and download music from vk.com.
Required active account in the vk social network, credentials must be placed in the configfile.pm

I try to avoid of using any of external perl libraries, so you don't need to load any of them.
All you need is curl programm installed for your OS. Read <a href="#faq">FAQ</a> if you have questions.

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

<table>
<tr> <th>$email <td>registration email.
<tr> <th>$pass <td>registration password.
<tr> <th>$download_dir <td>full path to directory where tracks will be placed, script can create it if it doesn't exist.
<tr> <th>$ua <td>user agent string, could be leaved as is.
</table>

### <a name="faq">FAQ</a>
**1. How to start script from everywhere, not only its directory**

Firstly, add link to script from some directory which writed in the $PATH env variable. ```echo $PATH``` - shows you which dir are in the $PATH already. For example: 
```ln -s PATH_TO_CLONED_DIR/vkmusic_downloader/vkmusic_downloader.pl /usr/local/bin```

Secondly, change 1 string in the script ```#!/usr/bin/perl``` to 
```#!/usr/bin/perl -I/PATH_TO_CLONED_DIR/vkmusic_downloader```

Now you could execute script from every directory like usual command

### Options and examples
    -s,--search name - search by given name
    -a,--artist - modificator for search by artist name
    -d,--debug - enable debug output
    -u,--usertracks - show all user tracks
    -h,-?,--help - Print this help and exit

    Show first 50 user tracks:
    ./vkmusic_downloader.pl
    Show all user tracks:
    ./vkmusic_downloader.pl -u
    Search by track name:
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
<table>
<tr> <th>[1]<td>consecutive number.
<tr> <th>Astrix<td>artist name.
<tr> <th>Beyond The Senses.<td>track name.
<tr> <th>(7:45)<td>track duration.
</table>

Then you could select any particular song or number of songs (by consecutive number) - write and push enter:

- digits through comma (1,3,4,10)
- digits through dash (1-12)
- all or * for downloading whole list
- h for help.

### Notes

Was tested for:
- MAC OS X
- Windows (Cygwin + curl compilation from src)

### Change log
**Version 1.1**

- Show all user added tracks

**Version 1.0**

- Shows first 50 user songs
- Can search by music name or by artist name
- Can download any count of searched songs
